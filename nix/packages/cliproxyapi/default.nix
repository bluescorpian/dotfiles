{ pkgs }:

# CLIProxyAPI — used here ONLY as OpenClaw's fallback provider. Unlike the
# primary proxy it does NOT shell out to the `claude` CLI; it runs its own
# `--claude-login` OAuth flow and talks to api.anthropic.com directly. That is
# the subscription-OAuth-reuse path Anthropic blocked in April 2026, so it is
# intentionally the secondary, invoked only when the sanctioned primary errors.
#
# Packaged from the upstream prebuilt release tarball (single Go binary).

pkgs.stdenv.mkDerivation rec {
  pname = "cliproxyapi";
  version = "7.2.105";

  src = pkgs.fetchurl {
    url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/v${version}/CLIProxyAPI_${version}_linux_amd64.tar.gz";
    hash = "sha256-9DKHKBX+haxLD4O1WYJTcl7qcKrkyVAlGUz1WPas7zE=";
  };

  # Tarball unpacks files at the top level (cli-proxy-api, LICENSE, config.example.yaml).
  sourceRoot = ".";

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs = [ pkgs.stdenv.cc.cc.lib ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 cli-proxy-api $out/bin/cli-proxy-api
    install -Dm644 config.example.yaml $out/share/cliproxyapi/config.example.yaml
    runHook postInstall
  '';

  meta = {
    description = "Multi-provider AI CLI proxy (Claude Max via subscription-OAuth reuse) — OpenAI/Anthropic-compatible";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    license = pkgs.lib.licenses.mit;
    mainProgram = "cli-proxy-api";
    platforms = [ "x86_64-linux" ];
  };
}
