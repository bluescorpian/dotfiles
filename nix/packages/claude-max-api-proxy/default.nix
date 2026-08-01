{ pkgs }:

# OpenAI-compatible proxy that fronts an authenticated Claude Code CLI, exposing
# a Claude Max/Pro subscription on http://127.0.0.1:3456/v1. It shells out to the
# `claude` binary (`claude -p`), which is the path Anthropic's Help Center
# currently sanctions for subscription-backed programmatic use.
#
# `claude` itself is NOT a build dependency — it is required on PATH at *runtime*
# and is provided by the systemd service (see services/openclaw.nix).

let
  rawSrc = pkgs.fetchFromGitHub {
    owner = "mattschwen";
    repo = "claude-max-api-proxy";
    # Pinned to a commit (no upstream tag); bump deliberately.
    rev = "d69b6a921e94fcd4d5c7a15c1a54ec1c0acfd4ca";
    hash = "sha256-+P2kTYM2a1T+3SIGfXR0Cibl3j+wM6VuyzuO/0lPnKw=";
  };

  # Upstream's committed package-lock.json omits `resolved`/`integrity` on a few
  # transitive deps (e.g. vary), so an offline `npm ci` fails with ENOTCACHED.
  # Vendor a regenerated, complete lockfile (same versions, full resolution) and
  # splice it into the source before the deps prefetch reads it.
  src = pkgs.runCommand "claude-max-api-proxy-src" { } ''
    cp -r ${rawSrc} $out
    chmod -R +w $out
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
pkgs.buildNpmPackage {
  pname = "claude-max-api-proxy";
  version = "1.5.0";
  inherit src;

  npmDepsHash = "sha256-xIVDrTQO27ERvnx50/jwEroF9HP+jKp0NH4w921vpWQ=";

  # TypeScript project: buildNpmPackage runs the "build" script (tsc) by default,
  # producing dist/. The "claude-max-api" bin is linked from package.json.

  meta = {
    description = "OpenAI-compatible proxy fronting the Claude Code CLI (Claude Max/Pro subscription)";
    homepage = "https://github.com/mattschwen/claude-max-api-proxy";
    license = pkgs.lib.licenses.mit;
    mainProgram = "claude-max-api";
  };
}
