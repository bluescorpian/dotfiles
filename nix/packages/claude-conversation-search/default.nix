{ pkgs }:

pkgs.rustPlatform.buildRustPackage {
  pname = "claude-conversation-search";
  version = "1.5.0";

  src = pkgs.fetchFromGitHub {
    owner = "ticpu";
    repo = "claude-conversation-search-mcp";
    rev = "v1.5.0";
    hash = "sha256-UPSttSnPtDqov0s4LNSGRxgotwu2E8K1mNaw4mtxjUw=";
  };

  cargoHash = "sha256-ITcAzjw1ifECA169L677Br6RrZxkwwscFhP048CB47E=";

  meta.description = "CLI + MCP server for searching Claude Code conversation history";
}
