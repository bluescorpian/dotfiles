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
      # Swap for anthropic/claude-opus-5 if you want the bigger model.
      model.default = "anthropic/claude-sonnet-5";
      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
      };
    };

    environmentFiles = [ envFile ];
  };

  # The module's container.hostUsers option — which normally grants an
  # interactive user access to the service state — is gated on
  # container.enable, so in native mode we join the group by hand. State dirs
  # are 2770 hermes:hermes, so group membership is what makes `hermes chat`
  # work as harry rather than erroring with EACCES on /var/lib/hermes.
  users.users.harry.extraGroups = [ "hermes" ];
}
