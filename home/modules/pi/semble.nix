{
  config,
  lib,
  pkgs,
  ...
}:
let
  json = pkgs.formats.json { };
  piConfigDir = config.programs.pi-coding-agent.configDir;
in
{
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

      Prefer Semble for semantic or exploratory code search. Use grep only when every literal occurrence is needed.
    '';
  };

  home.packages = [ pkgs.semble ];

  home.file."${piConfigDir}/mcp.json" = {
    source = json.generate "pi-mcp.json" {
      mcpServers = {
        semble = {
          command = "${pkgs.semble}/bin/semble";
        };
      };
    };
  };

  home.file."${piConfigDir}/agents/semble-search.md" = {
    source = ./semble-search.md;
  };
}
