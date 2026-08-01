{ domain, pkgs, pkgs-unstable, config, openclaw-pkg, claude-code-pkg, ... }:

# OpenClaw — self-hosted personal AI assistant, backed by Harry's Claude Max
# subscription via a local proxy.
#
# Topology (everything but Caddy is bound to localhost + firewalled):
#   openclaw gateway (:18789) --> claude-native (:8317, PRIMARY,  OAuth-reuse)
#                             \-> claude-cli    (:3456, FALLBACK, sanctioned)
#   Caddy openclaw.hrry.sh (public) --> gateway :18789
#
# Primary  = CLIProxyAPI. No Claude CLI: it holds its own subscription OAuth and
#            speaks the native Anthropic Messages API, so prompt caching,
#            extended thinking and tool_use blocks survive end to end. That is
#            subscription-OAuth reuse — the mechanism Anthropic blocked in April
#            2026 — so it is the ban-prone path, chosen deliberately for the
#            Anthropic-native feature set.
# Fallback = claude-max-api-proxy: shells out to `claude -p`, the path Anthropic
#            currently permits. OpenAI-shaped, so no prompt caching — but if the
#            primary is ever cut off, the agent degrades onto a compliant path
#            instead of going dark.
#
# Caching note: OpenClaw emits cache_control {type:"ephemeral"} for any
# anthropic-messages provider, so ~5-minute caching works through the local
# proxy. The 1-hour extended TTL is gated on the endpoint hostname being
# api.anthropic.com (or *.aiplatform.googleapis.com), which a localhost proxy
# cannot satisfy — see resolveAnthropicEphemeralCacheControl in the gateway.
#
# MANUAL, ONE-TIME STEPS (cannot be done declaratively — see task summary):
#   1. Create /etc/openclaw/gateway.env -> OPENCLAW_GATEWAY_TOKEN=<random hex>
#   2. Log the primary in. The OAuth callback lands on localhost:54545, which
#      must reach the VPS, so tunnel it from a machine with a browser:
#        ssh -L 54545:localhost:54545 vps
#        sudo -u clawproxy -H cli-proxy-api --config /etc/cliproxyapi/config.yaml \
#          -claude-login -no-browser
#   3. Log the fallback in: sudo -u clawproxy -H bash -lc \
#        'CLAUDE_CONFIG_DIR=/var/lib/clawproxy/.claude claude'   (browser OAuth)
#   4. Pair each browser once. Opening the UI queues a request; approve it with:
#        TOK=$(sudo sed -n 's/^OPENCLAW_GATEWAY_TOKEN=//p' /etc/openclaw/gateway.env)
#        sudo -u openclaw env HOME=/var/lib/openclaw \
#          OPENCLAW_CONFIG_PATH=/etc/openclaw/openclaw.json \
#          OPENCLAW_STATE_DIR=/var/lib/openclaw \
#          openclaw devices list --token "$TOK"      # then `devices approve <id>`
#      Request IDs are short-lived — re-list if approve says "no pending request".

let
  gatewayPort = 18789;
  cliProxyPort = 3456; # claude-max-api-proxy (fallback, spawns `claude -p`)
  nativeProxyPort = 8317; # CLIProxyAPI (primary, native Anthropic Messages)
  subdomain = "openclaw.${domain}";

  # Built against unstable: stable-24.11's buildNpmPackage predates the v2 deps
  # fetcher claude-max-api-proxy needs, and it keeps builds matching the hashes.
  claude-max-api-proxy = import ../../../packages/claude-max-api-proxy { pkgs = pkgs-unstable; };
  cliproxyapi = import ../../../packages/cliproxyapi { pkgs = pkgs-unstable; };

  # Anything that shells out to the Claude Code CLI needs it (and its helpers) on PATH.
  claudeRuntime = [ claude-code-pkg pkgs.coreutils pkgs.git pkgs.bash ];

  # No secrets in here: OAuth creds live in auth-dir (populated by --claude-login),
  # and the control panel is disabled so it never phones GitHub at runtime.
  # Materialized at a stable /etc path so the manual login uses the same config.
  cliproxyConfigText = ''
    host: "127.0.0.1"
    port: ${toString nativeProxyPort}
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

  # ---- FALLBACK proxy: claude-max-api-proxy (sanctioned CLI-subprocess) ----
  systemd.services.claude-max-api-proxy = {
    description = "claude-max-api-proxy (fallback: Claude Max via `claude -p`)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = {
      PORT = toString cliProxyPort;
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

  # ---- PRIMARY proxy: CLIProxyAPI (native Anthropic Messages, OAuth-reuse) ----
  systemd.services.cliproxyapi = {
    description = "CLIProxyAPI (primary: Claude Max via native Anthropic API)";
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

      # Custom (non-bundled) providers MUST declare baseUrl + a `models` array,
      # else the gateway exits 78.
      models.providers = {
        # PRIMARY — native Anthropic Messages. No /v1 suffix: the Anthropic SDK
        # is handed this as its baseURL and appends /v1/messages itself.
        claude-native = {
          baseUrl = "http://127.0.0.1:${toString nativeProxyPort}";
          apiKey = "not-needed";
          api = "anthropic-messages";
          # Fully-versioned ids only — CLIProxyAPI does not accept family
          # aliases. Bump these as newer models appear in its /v1/models.
          #
          # maxTokens is REQUIRED here: the Anthropic Messages API demands
          # max_tokens on every request, and without it the transport refuses
          # to send ("requires a positive maxTokens value"). 64000 verified
          # accepted by both models against this proxy.
          models = [
            {
              id = "claude-opus-5";
              name = "Claude Opus 5 (native)";
              maxTokens = 64000;
              contextWindow = 200000;
            }
            {
              id = "claude-sonnet-5";
              name = "Claude Sonnet 5 (native)";
              maxTokens = 64000;
              contextWindow = 200000;
            }
          ];
        };
        # FALLBACK — OpenAI-shaped, in front of the Claude CLI.
        claude-cli = {
          baseUrl = "http://127.0.0.1:${toString cliProxyPort}/v1";
          apiKey = "not-needed";
          api = "openai-completions";
          # This proxy takes family aliases and lets the CLI resolve the current
          # versioned id at runtime, so it tracks the latest models by itself.
          models = [
            { id = "opus"; name = "Claude Opus (CLI fallback)"; }
            { id = "sonnet"; name = "Claude Sonnet (CLI fallback)"; }
          ];
        };
      };
      agents.defaults.model = {
        primary = "claude-native/claude-opus-5";
        fallbacks = [ "claude-cli/opus" ];
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
