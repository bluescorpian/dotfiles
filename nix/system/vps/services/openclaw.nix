{ domain, pkgs, pkgs-unstable, config, openclaw-pkg, claude-code-pkg, ... }:

# OpenClaw — self-hosted personal AI assistant, backed by Harry's Claude Max
# subscription via a local proxy.
#
# Topology (everything but Caddy is bound to localhost + firewalled):
#   openclaw gateway (:18789) --> claude-proxy   (:3456, PRIMARY, sanctioned)
#                             \-> claude-fallback (:8317, FALLBACK, OAuth-reuse)
#   Caddy openclaw.hrry.sh (public, basic_auth) --> gateway :18789
#
# Primary  = claude-max-api-proxy: shells out to `claude -p` (the path Anthropic
#            currently permits for subscription-backed programmatic use).
# Fallback = CLIProxyAPI: subscription-OAuth reuse (the April-2026-blocked path);
#            only exercised when the primary errors. Ban-prone by design.
#
# MANUAL, ONE-TIME STEPS (cannot be done declaratively — see task summary):
#   1. Create /etc/openclaw/gateway.env -> OPENCLAW_GATEWAY_TOKEN=<random hex>
#   2. Log the primary in:  sudo -u clawproxy -H bash -lc \
#        'CLAUDE_CONFIG_DIR=/var/lib/clawproxy/.claude claude'   (browser OAuth)
#   3. Log the fallback in: sudo -u clawproxy -H bash -lc \
#        'cli-proxy-api --claude-login --config /etc/cliproxyapi/config.yaml'
#   4. Pair each browser once. Opening the UI queues a request; approve it with:
#        TOK=$(sudo sed -n 's/^OPENCLAW_GATEWAY_TOKEN=//p' /etc/openclaw/gateway.env)
#        sudo -u openclaw env HOME=/var/lib/openclaw \
#          OPENCLAW_CONFIG_PATH=/etc/openclaw/openclaw.json \
#          OPENCLAW_STATE_DIR=/var/lib/openclaw \
#          openclaw devices list --token "$TOK"      # then `devices approve <id>`
#      Request IDs are short-lived — re-list if approve says "no pending request".

let
  gatewayPort = 18789;
  primaryProxyPort = 3456; # claude-max-api-proxy
  fallbackProxyPort = 8317; # CLIProxyAPI
  subdomain = "openclaw.${domain}";

  # Built against unstable: stable-24.11's buildNpmPackage predates the v2 deps
  # fetcher the primary needs, and it keeps builds matching the resolved hashes.
  claude-max-api-proxy = import ../../../packages/claude-max-api-proxy { pkgs = pkgs-unstable; };
  cliproxyapi = import ../../../packages/cliproxyapi { pkgs = pkgs-unstable; };

  # Anything that shells out to the Claude Code CLI needs it (and its helpers) on PATH.
  claudeRuntime = [ claude-code-pkg pkgs.coreutils pkgs.git pkgs.bash ];

  # No secrets in here: OAuth creds live in auth-dir (populated by --claude-login),
  # and the control panel is disabled so it never phones GitHub at runtime.
  # Materialized at a stable /etc path so the manual login uses the same config.
  cliproxyConfigText = ''
    host: "127.0.0.1"
    port: ${toString fallbackProxyPort}
    auth-dir: "/var/lib/cliproxyapi/auth"
    api-keys:
      - "not-needed"
    remote-management:
      disable-control-panel: true
    debug: false
  '';
in
{
  # `claude`, `cli-proxy-api` and `openclaw` on the system PATH so the one-time
  # logins and `openclaw devices approve` runs don't need /nix/store paths.
  environment.systemPackages = [ claude-code-pkg cliproxyapi openclaw-pkg ];

  environment.etc."cliproxyapi/config.yaml".text = cliproxyConfigText;

  # ---- Shared system user for both subscription proxies ----
  users.groups.clawproxy = { };
  users.users.clawproxy = {
    isSystemUser = true;
    group = "clawproxy";
    home = "/var/lib/clawproxy";
    createHome = true;
    # Interactive shell so `sudo -u clawproxy -i` works for the one-time logins.
    shell = pkgs.bashInteractive;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/clawproxy 0700 clawproxy clawproxy - -"
    "d /var/lib/clawproxy/.claude 0700 clawproxy clawproxy - -"
    "d /var/lib/cliproxyapi 0700 clawproxy clawproxy - -"
    "d /var/lib/cliproxyapi/auth 0700 clawproxy clawproxy - -"
    "d /etc/openclaw 0755 root root - -"
  ];

  # ---- PRIMARY proxy: claude-max-api-proxy (sanctioned CLI-subprocess) ----
  systemd.services.claude-max-api-proxy = {
    description = "claude-max-api-proxy (primary: Claude Max via `claude -p`)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = {
      PORT = toString primaryProxyPort;
      HOST = "127.0.0.1";
      HOME = "/var/lib/clawproxy";
      CLAUDE_CONFIG_DIR = "/var/lib/clawproxy/.claude";
    };
    path = claudeRuntime;
    serviceConfig = {
      User = "clawproxy";
      Group = "clawproxy";
      WorkingDirectory = "/var/lib/clawproxy";
      ExecStart = "${claude-max-api-proxy}/bin/claude-max-api";
      Restart = "always";
      RestartSec = 3;
    };
  };

  # ---- FALLBACK proxy: CLIProxyAPI (OAuth-reuse; only on primary failure) ----
  systemd.services.cliproxyapi = {
    description = "CLIProxyAPI (fallback: Claude Max via OAuth-reuse)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = { HOME = "/var/lib/cliproxyapi"; };
    path = [ pkgs.coreutils ];
    serviceConfig = {
      User = "clawproxy";
      Group = "clawproxy";
      WorkingDirectory = "/var/lib/cliproxyapi";
      ExecStart = "${cliproxyapi}/bin/cli-proxy-api --config /etc/cliproxyapi/config.yaml";
      Restart = "always";
      RestartSec = 3;
    };
  };

  # ---- OpenClaw gateway ----
  services.openclaw-gateway = {
    enable = true;
    package = openclaw-pkg;
    port = gatewayPort;
    # OPENCLAW_GATEWAY_TOKEN lives out-of-repo (repo is public). Leading '-' =
    # tolerate the file being absent until it's created on the box.
    environmentFiles = [ "-/etc/openclaw/gateway.env" ];
    config = {
      # Required: without an explicit mode the gateway refuses to start
      # ("existing config is missing gateway.mode") and exits 78/EX_CONFIG.
      # The dashboard token itself comes from OPENCLAW_GATEWAY_TOKEN (gateway.env).
      gateway.mode = "local";

      # The Control UI is served through Caddy, so the browser's origin is the
      # public URL rather than the gateway host; without this the gateway rejects
      # the WebSocket handshake ("Browser origin not allowed").
      gateway.controlUi.allowedOrigins = [ "https://${subdomain}" ];

      # We sit behind Caddy on loopback. Without this every request looks like it
      # came from 127.0.0.1, so any "local client" trust shortcuts would apply to
      # anyone who gets past the Caddy login. Trusting x-forwarded-for only from
      # loopback makes the gateway see real client IPs and treat them as remote.
      gateway.trustedProxies = [ "127.0.0.1" "::1" ];

      # Both proxies are OpenAI-compatible on /v1. Custom (non-bundled) providers
      # MUST declare baseUrl + a `models` array, else the gateway exits 78.
      models.providers = {
        claude-proxy = {
          baseUrl = "http://127.0.0.1:${toString primaryProxyPort}/v1";
          apiKey = "not-needed";
          api = "openai-completions";
          # The proxy takes family aliases (opus/sonnet/haiku) and lets the Claude
          # CLI resolve the current versioned id at runtime — so this tracks the
          # latest Opus/Sonnet automatically instead of pinning a stale version.
          models = [
            { id = "opus"; name = "Claude Opus (Max subscription)"; }
            { id = "sonnet"; name = "Claude Sonnet (Max subscription)"; }
          ];
        };
        claude-fallback = {
          baseUrl = "http://127.0.0.1:${toString fallbackProxyPort}/v1";
          apiKey = "not-needed";
          api = "openai-completions";
          # NB: CLIProxyAPI advertises no models until its own OAuth login is done;
          # verify these ids against `curl localhost:8317/v1/models` afterwards, as
          # it may want fully-versioned Anthropic ids rather than family aliases.
          models = [
            { id = "opus"; name = "Claude Opus (fallback)"; }
            { id = "sonnet"; name = "Claude Sonnet (fallback)"; }
          ];
        };
      };
      agents.defaults.model = {
        primary = "claude-proxy/opus";
        fallbacks = [ "claude-fallback/opus" ];
      };
    };
  };

  # The gateway config lives in /etc, so a config-only change leaves the unit
  # untouched and systemd won't restart it — the new settings would silently not
  # apply until the next manual restart. Tie the unit to the rendered config.
  systemd.services.openclaw-gateway.restartTriggers = [
    config.environment.etc."openclaw/openclaw.json".source
  ];

  # ---- Public entrypoint: openclaw.hrry.sh ----
  # Deliberately NO Caddy basic_auth. The gateway enforces its own, stronger auth
  # (origin allowlist + gateway token + device pairing that needs operator
  # approval), so a shared password added no security — while re-running a
  # bcrypt(cost 14) check on every request and re-triggering the browser's auth
  # dialog on each WebSocket reconnect, which the Control UI does constantly.
  services.caddy.virtualHosts.${subdomain}.extraConfig = ''
    reverse_proxy localhost:${toString gatewayPort}
  '';
}
