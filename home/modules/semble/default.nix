{
  config,
  lib,
  pkgs,
  ...
}:
let
  piConfigDir = config.programs.pi-coding-agent.configDir;
  sembleAgent = "${pkgs.semble.src}/src/semble/agents/pi.md";
in
{
  programs.mcp = {
    enable = true;
    servers.semble = {
      command = "${pkgs.semble}/bin/semble";
      lifecycle = "lazy";
    };
  };

  programs.pi-coding-agent = {
    extraPackages = [ pkgs.semble ];

    context = lib.mkAfter ''
      ## Code Search

      Use `semble search` to find code by describing what it does or naming a symbol/identifier, instead of grep:

      ```bash
      semble search "authentication flow" ./my-project --max-snippet-lines 10
      semble search "save_pretrained" ./my-project
      semble search "save model to disk" ./my-project --top-k 10
      ```

      The index is built on first run and cached for subsequent runs. It is invalidated automatically when files change.

      Use `--content docs` to search documentation and prose, `--content config` for config files, or `--content all` to search code, docs, and config:

      ```bash
      semble search "deployment guide" ./my-project --content docs
      semble search "database host port" ./my-project --content config
      semble search "authentication" ./my-project --content all
      ```

      Use `semble find-related` to discover code similar to a known location:

      ```bash
      semble find-related src/auth.py 42 ./my-project
      ```

      Semble is also configured as a Pi MCP server. Prefer the MCP tools `mcp_semble_search` and `mcp_semble_find_related` when they are available; otherwise use the `semble` CLI.

      A dedicated `semble-search` Pi subagent is installed for broader codebase exploration tasks.

      Prefer Semble for semantic or exploratory code search. Use grep only when every literal occurrence is needed.
    '';
  };

  home.packages = [ pkgs.semble ];

  home.file = {
    # pi-subagents discovers user agents here.
    "${piConfigDir}/agents/semble-search.md" = {
      source = sembleAgent;
    };

    # Semble's Pi installation docs currently list this path for Pi agents.
    ".pi/agents/semble-search.md" = {
      source = sembleAgent;
    };
  };
}
