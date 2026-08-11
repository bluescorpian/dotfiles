{ pkgs }:

# Firecrawl's CLI — web scrape/search/crawl/map, driven by the `firecrawl`
# Claude Code plugin's skills. Not in nixpkgs, and the plugin's README tells you
# to `npm install -g firecrawl-cli`, which can't work here: nixpkgs' node is a
# read-only store path, so npm/pnpm have nowhere to put a global install.
#
# Built from the published npm tarball rather than the GitHub repo because the
# tarball already ships the compiled dist/ (the repo's build is `tsc` + a pnpm
# lockfile we'd otherwise have to reproduce). To bump: change version, refresh
# `hash` (nix-prefetch-url + nix hash convert), then regenerate package-lock.json
# with `npm install --package-lock-only --omit=dev` against the new package.json
# and refresh npmDepsHash.

pkgs.buildNpmPackage rec {
  pname = "firecrawl-cli";
  version = "1.19.29";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/firecrawl-cli/-/firecrawl-cli-${version}.tgz";
    hash = "sha256-Zot1ggImY4/+Cr2wa+OynTH9Mcid2cFG6IBcpvDJYT4=";
  };

  # The tarball ships no lockfile, so buildNpmPackage has nothing to pin against;
  # vendor one alongside this file (same reason claude-conversation-search vendors
  # its Cargo.lock). `prepare` runs husky, a git-hook installer that's both absent
  # from the dev-dep-free install and meaningless in a sandbox build.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    ${pkgs.jq}/bin/jq 'del(.scripts.prepare)' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';

  npmDepsHash = "sha256-qqA5YK+EXve8514Z831sd+UnRrWyBR5LIN1qQE9m56E=";

  # dist/ is prebuilt in the tarball; there is no build script to run.
  dontNpmBuild = true;
  npmFlags = [ "--omit=dev" ];

  meta = {
    description = "Command-line interface for Firecrawl — scrape, crawl, and extract data from any website";
    homepage = "https://docs.firecrawl.dev/cli";
    license = pkgs.lib.licenses.isc;
    mainProgram = "firecrawl";
  };
}
