# Hermes Agent (Nous Research) — native systemd service, no container.
#
# CLI-only deployment: no messaging adapters are enabled, so nothing is exposed
# through Caddy and there is no subdomain. Talk to it over SSH with
# `hermes chat` or `hermes --tui`.
#
# Config here is authoritative — the module runs hermes in "managed mode", which
# blocks `hermes setup`, `hermes config edit` and `hermes config set` on the box.
# Change settings here and rebuild.
#
# The API key lives in ${envFile}, deliberately outside this repo (it is public).
# The module concatenates that file into $HERMES_HOME/.env at activation time,
# so the key must be added before hermes can reach a provider:
#
#   echo "OPENROUTER_API_KEY=sk-or-..." | sudo install -m 0600 -o hermes -g hermes /dev/stdin /var/lib/hermes/env
#
# then rebuild (activation regenerates .env; a bare restart is not enough).
{ ... }:
let
  envFile = "/var/lib/hermes/env";
in {
  services.hermes-agent = {
    enable = true;

    # Puts the `hermes` CLI on the system PATH and sets HERMES_HOME globally so
    # an interactive shell shares sessions/memories/cron with the gateway
    # service instead of creating its own ~/.hermes.
    addToSystemPackages = true;

    settings = {
      # Via OpenRouter (the module's default provider — no base_url needed).
      # DeepSeek V4 Pro rather than claude-sonnet-5 on cost: $0.44/$0.87 per
      # million tokens in/out against Sonnet's $2/$10, so ~4.6x cheaper in and
      # ~11x out. deepseek-v4-flash is cheaper again ($0.09/$0.18) if this still
      # costs more than it's worth.
      model.default = "deepseek/deepseek-v4-pro";
      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
      };
    };

    # Matrix is the only messaging platform enabled. Signal was considered and
    # dropped; Telegram/Discord/Slack are deliberately absent — the bot API for
    # those is not end-to-end encrypted.
    #
    # `matrix` is Linux-only and pulls mautrix + python-olm into the sealed venv.
    # It cannot be installed at runtime: the Nix store is read-only, so any
    # optional extra has to be built in here.
    extraDependencyGroups = [ "matrix" ];

    # Non-secret, so safe to have in the world-readable Nix store. Everything
    # identifying or authenticating lives in ${envFile} instead — see below.
    environment = {
      MATRIX_HOMESERVER = "https://matrix.org";
      # `optional` tries E2EE but keeps working unencrypted if crypto fails to
      # initialise — i.e. it can silently downgrade. mautrix + python-olm are
      # confirmed present in the built closure, so it should engage; grep the
      # journal for "E2EE" after first start to be sure. `required` fails closed
      # instead, if you'd rather it refuse to run than send plaintext.
      MATRIX_E2EE_MODE = "optional";
      # Rooms need an @mention; DMs always get a response.
      MATRIX_REQUIRE_MENTION = "true";
      # The bot auto-accepts room invites, so without this anyone who can invite
      # it into a room could reach it. Keep public-room joins off.
      MATRIX_ALLOW_PUBLIC_ROOMS = "false";
    };

    # Secrets and personal identifiers, kept out of this public repo:
    #   MATRIX_ACCESS_TOKEN   full access to the bot's Matrix account
    #   MATRIX_ALLOWED_USERS  your @user:matrix.org — who may talk to the bot
    #   MATRIX_ALLOWED_ROOMS  which rooms may trigger a turn
    #   MATRIX_RECOVERY_KEY   optional; lets the bot self-sign its device so
    #                         Element will share encryption sessions with it
    # Upstream is explicit that a locked-down deployment sets BOTH the user and
    # room allowlists: with either unset, anything that reaches the bot in a
    # joined room can trigger an agent turn.
    environmentFiles = [ envFile ];
  };

  # The module's container.hostUsers option — which normally grants an
  # interactive user access to the service state — is gated on
  # container.enable, so in native mode we join the group by hand. State dirs
  # are 2770 hermes:hermes, so group membership is what makes `hermes chat`
  # work as harry rather than erroring with EACCES on /var/lib/hermes.
  users.users.harry.extraGroups = [ "hermes" ];
}
