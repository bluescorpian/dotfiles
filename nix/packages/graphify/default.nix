{ pkgs }:

# graphify turns a codebase into a queryable knowledge graph for AI coding
# assistants. Not in nixpkgs (PyPI name: graphifyy), and neither are 19 of the
# ~30 tree-sitter grammars it parses with — see mkGrammar below.

let
  py = pkgs.python3Packages;

  # PyPI ships every tree-sitter grammar as a prebuilt abi3 manylinux wheel, so
  # these need no compiler and no per-Python rebuild — just autoPatchelf onto the
  # Nix loader. Building the sdists instead does NOT work: they omit the bundled
  # tree_sitter/parser.h that src/parser.c includes (nixpkgs' own grammar
  # packages sidestep this by building from the GitHub repos, not the sdists).
  # To bump one, take url + digests.sha256 from https://pypi.org/pypi/<name>/json.
  mkGrammar =
    { pname, version, url, hash }:
    py.buildPythonPackage {
      inherit pname version;
      format = "wheel";
      src = pkgs.fetchurl { inherit url hash; };
      nativeBuildInputs = [ pkgs.autoPatchelfHook ];
      pythonImportsCheck = [ (builtins.replaceStrings [ "-" ] [ "_" ] pname) ];
    };

  grammars = map mkGrammar [
    { pname = "tree-sitter-typescript"; version = "0.23.2";
      url = "https://files.pythonhosted.org/packages/49/d1/a71c36da6e2b8a4ed5e2970819b86ef13ba77ac40d9e333cb17df6a2c5db/tree_sitter_typescript-0.23.2-cp39-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-6W02uFvKzeuP9cJhjXVZPvEuuvG06s40d+K9squxdSw="; }
    { pname = "tree-sitter-go"; version = "0.25.0";
      url = "https://files.pythonhosted.org/packages/86/fb/b30d63a08044115d8b8bd196c6c2ab4325fb8db5757249a4ef0563966e2e/tree_sitter_go-0.25.0-cp310-abi3-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256-BLOzy0r/GOdOKNSbcWxvJMtx3f3WZ2iYfibk0PqBL3Q="; }
    { pname = "tree-sitter-java"; version = "0.23.5";
      url = "https://files.pythonhosted.org/packages/29/09/e0d08f5c212062fd046db35c1015a2621c2631bc8b4aae5740d7adb276ad/tree_sitter_java-0.23.5-cp39-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-NwsgS5UAuEf20MWtWEBFgxzuaemj5Nh4U1055KfkxPE="; }
    { pname = "tree-sitter-groovy"; version = "0.1.2";
      url = "https://files.pythonhosted.org/packages/c6/b7/451ac5e158f2418fea7eb0744254dd27238359c070420d69d711aaf06356/tree_sitter_groovy-0.1.2-cp39-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-npOOnCzV/bCP0bKNfWIdFeqVmhekvAt3gz4HqU/n0mM="; }
    { pname = "tree-sitter-c"; version = "0.24.2";
      url = "https://files.pythonhosted.org/packages/e9/8c/0dfb88d726f8821d1c4c36042f092be974a800afd734307a595b8604190c/tree_sitter_c-0.24.2-cp310-abi3-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256-UEHvZ+tozmvIuwsfjvOlWFzlI9rgx+7BCasGJ911rt4="; }
    { pname = "tree-sitter-cpp"; version = "0.23.4";
      url = "https://files.pythonhosted.org/packages/6a/4d/23e390234d2acd351f5563b1079c515d7c1fe13ddb7392cee543be74dda3/tree_sitter_cpp-0.23.4-cp39-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-dz0sr8CLvA+Zhof6M/QvN4waNxzbWChwxNE6uwYJJwY="; }
    { pname = "tree-sitter-ruby"; version = "0.23.1";
      url = "https://files.pythonhosted.org/packages/23/dd/1171b5dd25da10f768732a20fb62d2e3ae66e3b42329351f2ce5bf723abb/tree_sitter_ruby-0.23.1-cp39-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-97zZOXK0yigDhW1P4PvQQSP/KcRZK7ufEqJ1KL0lI0E="; }
    { pname = "tree-sitter-kotlin"; version = "1.1.0";
      url = "https://files.pythonhosted.org/packages/65/bd/0f3aac45eb88b6b3173ac9c23bc41d8865943cbbe1caaafc001cd1b73c90/tree_sitter_kotlin-1.1.0-cp39-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-mpKv4ktjTPkUxYEq8PXFMYSxwYvfbuVQXIOvrIH2v2w="; }
    { pname = "tree-sitter-scala"; version = "0.26.0";
      url = "https://files.pythonhosted.org/packages/3f/61/e64e1c2b2552f5dc556c9710ecf935ed531efa8a3eb9de9ad4e7c95f6e97/tree_sitter_scala-0.26.0-cp39-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-z/F4qTENhZ6Bmm/hDzErbkI9mh0Myl5jVKRf4AQWd74="; }
    { pname = "tree-sitter-php"; version = "0.24.1";
      url = "https://files.pythonhosted.org/packages/9a/c6/fd863a7a779d0ab67688939eba0e08bff7b1ffe731288d3d3610df21217b/tree_sitter_php-0.24.1-cp310-abi3-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256-ehQEow8pckmKzgQLAClzi42sRdChKTLMuLYF65S6++Q="; }
    { pname = "tree-sitter-swift"; version = "0.7.3";
      url = "https://files.pythonhosted.org/packages/e1/9a/55f6cc9aad9079facf166d616472fd8e05007cbee9c62b749e153bf0521d/tree_sitter_swift-0.7.3-cp38-abi3-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256-84/utPc1DIsw1Weg3Ai/HuqmfCQbaIjXKkWosaSqcYc="; }
    { pname = "tree-sitter-lua"; version = "0.5.0";
      url = "https://files.pythonhosted.org/packages/45/2b/1edfd9bef9a1cc11047cd87ca9c60707b8425080cfc0498a7d3bc762d783/tree_sitter_lua-0.5.0-cp310-abi3-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256-XsRIyFT+oyQUoESRR9ZIvFut33oDVwCMSr4yads1Nwo="; }
    { pname = "tree-sitter-zig"; version = "1.1.2";
      url = "https://files.pythonhosted.org/packages/78/02/275523eb05108d83e154f52c7255763bac8b588ae14163563e19479322a7/tree_sitter_zig-1.1.2-cp39-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-6SRQncrFpgVNo1fj1rzzfqgphO4dKjdlaXU9MvYeqLs="; }
    { pname = "tree-sitter-powershell"; version = "0.26.4";
      url = "https://files.pythonhosted.org/packages/de/ff/5bba5fef4b3808ade114512ebf44e0c192050cc825cdcf42fa2043e5abd0/tree_sitter_powershell-0.26.4-cp310-abi3-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256-VlCOSseq0eOyby75a40rYLFJxO+gwjdC6R6AmhHbc+4="; }
    { pname = "tree-sitter-elixir"; version = "0.3.5";
      url = "https://files.pythonhosted.org/packages/31/35/78c94e164542ad08098b83cb7e046261f3ab2edade96e29727dd209bfa35/tree_sitter_elixir-0.3.5-cp39-abi3-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256-6/40kaPQCsULEqO/yrscVk84Ce2KCVCZ/of0nWs5h+Y="; }
    { pname = "tree-sitter-objc"; version = "3.0.2";
      url = "https://files.pythonhosted.org/packages/60/cd/a153a4268b9b405a69ee3e427f19fc570a3c63d4b4d7766bee5a7ba28744/tree_sitter_objc-3.0.2-cp39-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-5xKCrJwJapZr8vpqTs2+pL0DfT4B6kqpu8ZNmkwAIvY="; }
    { pname = "tree-sitter-julia"; version = "0.23.1";
      url = "https://files.pythonhosted.org/packages/0b/4c/09534d31ab95c3da2284f538bb134bf6fe064770c0bf6fe4fb6f2b028d9e/tree_sitter_julia-0.23.1-cp39-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-fU9q6TgZj8C+m26nYxOt4k/NuJvgGnkeDMkMiPrldD0="; }
    { pname = "tree-sitter-verilog"; version = "1.0.3";
      url = "https://files.pythonhosted.org/packages/2a/c1/8782535dbb6ea1f3556eb2bc473f5f131339739278775171fc42b0a57536/tree_sitter_verilog-1.0.3-cp39-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-dH3X1LyV+zibw3Il+C0W8MQFSYVumiRL4/+de/5itzA="; }
    { pname = "tree-sitter-fortran"; version = "0.6.0";
      url = "https://files.pythonhosted.org/packages/57/86/0923f061e36f229d99660a8f53f8e3b57da459e08512c09e256de820c472/tree_sitter_fortran-0.6.0-cp39-abi3-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256-rEgAtKvBsl5uerSj8uridMWxkQe+sY06RzwPZ1CcdIY="; }
    # The `terraform` extra. Pulled in because wedded-world has .tf/.hcl that
    # otherwise contribute nothing to the graph.
    { pname = "tree-sitter-hcl"; version = "1.2.0";
      url = "https://files.pythonhosted.org/packages/ee/0a/01bb627044d273e8e506edff8ab773e562ba447b5790b789f62e47a5e754/tree_sitter_hcl-1.2.0-cp310-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-kVdj2mYwYQwu+3r+ExRfUP64BDcyp0+brniBEhJXjT0="; }
  ];
  version = "0.9.32";

  graphify = py.buildPythonApplication {
    pname = "graphify";
    inherit version;
    format = "wheel";

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/fe/54/7eae9e8056dc924a9f7607405a30485a93e4c4149dad99ef8ed4fd0ec967/graphifyy-${version}-py3-none-any.whl";
      hash = "sha256-ffZ6s73UcqUSQ+YdOwRV3djxw8Wm95RcM8eyke0xooA=";
    };

    # Core, plus the `sql` and `terraform` extras — without them graphify
    # silently drops .sql/.tf/.hcl files from the graph, which cost wedded-world
    # 133 + 10 files. The remaining extras (mcp, pdf, neo4j, video, office, and
    # the LLM backends) are deliberately left out.
    dependencies = (with py; [
      networkx
      numpy
      rapidfuzz
      tree-sitter
      tree-sitter-bash
      tree-sitter-c-sharp
      tree-sitter-javascript
      tree-sitter-json
      tree-sitter-python
      tree-sitter-rust
      tree-sitter-sql
    ]) ++ grammars;

    pythonImportsCheck = [ "graphify" ];

    # The Claude Code skill that `graphify install` would copy into
    # ~/.claude/skills/graphify. Exposed here so home-manager can symlink it
    # instead — running the installer for real would also rewrite
    # ~/.claude/CLAUDE.md, which is a read-only store symlink on this system.
    passthru.skill = pkgs.runCommand "graphify-skill-${version}" { } ''
      src=${graphify}/${py.python.sitePackages}/graphify
      mkdir -p $out
      cp $src/skill.md $out/SKILL.md
      cp -r $src/skills/claude/references $out/references
      echo ${version} > $out/.graphify_version
    '';

    meta = {
      description = "Turn a folder of code, docs, or papers into a queryable knowledge graph for AI coding assistants";
      homepage = "https://github.com/Graphify-Labs/graphify";
      license = pkgs.lib.licenses.asl20;
      mainProgram = "graphify";
    };
  };
in
graphify
