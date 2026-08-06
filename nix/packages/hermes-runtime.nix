# Reproducible document/content runtime for Hermes terminal calls and cron jobs.
#
# This intentionally stays outside Hermes' sealed Python venv.  The agent
# service gets these executables through `extraPackages`, while the flake's
# devShell exposes the same package set for manual use.
{ pkgs }:
let
  python = pkgs.python3.withPackages (ps: with ps; [
    pypdf
    pdfplumber
    reportlab
    openpyxl
    pandas
    markitdown
    lxml
    defusedxml
    youtube-transcript-api
  ]);

  # Several bundled skill scripts and their docs call `python`, while Nix's
  # Python package exposes `python3`. Keep both names pointed at precisely the
  # same isolated interpreter.
  pythonCompat = pkgs.writeShellScriptBin "python" ''
    exec ${python}/bin/python3 "$@"
  '';

  # The Node dependencies are lockfile-pinned in ./hermes-node-runtime.  This
  # is a runtime modules derivation, not a global npm installation.
  nodeModules = pkgs.buildNpmPackage {
    pname = "hermes-node-modules";
    version = "1.0.0";
    src = ./hermes-node-runtime;
    npmDepsHash = "sha256-+kBaGXNIgfQCAqwriznkjjTc0PLDfzNXvDeoXztxBfE=";
    dontNpmBuild = true;
    installPhase = ''
      mkdir -p "$out/lib"
      cp -R node_modules "$out/lib/node_modules"
    '';
  };

  # Node's NODE_PATH is not inherited by Hermes globally: only this dedicated
  # wrapper gets it, so its dependency resolution remains reproducible and does
  # not alter Claude Code or other Node CLIs. It supports CommonJS `require()`
  # from arbitrary working directories, which is what the docx/pptxgenjs skill
  # generators use.
  node = pkgs.runCommand "hermes-node" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } ''
    mkdir -p "$out/bin"
    makeWrapper ${pkgs.nodejs}/bin/node "$out/bin/node" \
      --set NODE_PATH ${nodeModules}/lib/node_modules
    makeWrapper ${pkgs.nodejs}/bin/npm "$out/bin/npm" \
      --set NODE_PATH ${nodeModules}/lib/node_modules
    makeWrapper ${pkgs.nodejs}/bin/npx "$out/bin/npx" \
      --set NODE_PATH ${nodeModules}/lib/node_modules
  '';
in {
  inherit python pythonCompat node nodeModules;

  packages = [
    python
    pythonCompat
    node
    pkgs.libreoffice
    pkgs.pandoc
    pkgs.poppler-utils
    pkgs.qpdf
  ];
}
