{ config, pkgs, ... }:
let
  json = pkgs.formats.json { };
  piConfigDir = config.programs.pi-coding-agent.configDir;
in
{
  programs.pi-coding-agent = {
    enable = true;
    package = pkgs.pi-coding-agent;

    extraPackages = [
      pkgs.nodejs
      config.programs.rtk.package
      pkgs.semble
      pkgs.git
      pkgs.direnv
      pkgs.systemd
      pkgs.hyprland
      pkgs.coin
      pkgs.hypr-notify
    ];

    settings = {
      lastChangelogVersion = "0.80.2";
      quietStartup = true;
      defaultProvider = "github-copilot";
      defaultModel = "gpt-5.5";
      defaultThinkingLevel = "medium";
      npmCommand = [ "${pkgs.nodejs}/bin/npm" ];
      packages = [
        "npm:pi-subagents"
        "npm:pi-mcp-extension"
        "npm:pi-web-access"
        "npm:@ayulab/pi-rewind"
        "pi-lens"

      ];
    };

    context = ''
      - Use fixup commits when fixing earlier commits in the same PR (using `git commit --fixup <commit-hash>`)
      - Look for existing commits to know how to format commit messages

      - Nix is available. If you cannot find a package, use `nix run nixpkgs#{packagename} -- ...` or `export PATH="$(nix build nixpkgs#{packagename})/bin:$PATH"`
      - If you are not able to find a Nix package for a command, use `nix-locate --minimal --at-root /bin/{command}`

      - Prefer long-form arguments over short-hands (--argument vs -a)
      - Avoid uncommon abbreviations in code and text; prefer full words (for example: "notification" over "notif", "ServiceDaemon" over "sd"). Single-letter names are never acceptable.

      - Read all skills that are related, instead of just one
      - When you have multiple tasks, read the related skill before each task

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

  home.packages = [
    pkgs.nodejs
    pkgs.semble
  ];

  home.sessionVariables.PI_SKIP_VERSION_CHECK = "1";

  home.file."${piConfigDir}/mcp.json" = {
    source = json.generate "pi-mcp.json" {
      mcpServers = {
        semble = {
          command = "${pkgs.semble}/bin/semble";
        };
      };
    };
  };

  home.file."${piConfigDir}/extensions/rtk.ts" = {
    source = ./rtk.ts;
  };

  home.file."${piConfigDir}/extensions/direnv.ts" = {
    source = ./extensions/direnv.ts;
  };

  home.file."${piConfigDir}/extensions/notify.ts" = {
    source = ./extensions/notify.ts;
  };

  home.file."${piConfigDir}/extensions/secret-filter.ts" = {
    source = ./extensions/secret-filter.ts;
  };

  home.file."${piConfigDir}/extensions/session-status.ts" = {
    source = ./extensions/session-status.ts;
  };

  home.file."${piConfigDir}/extensions/systemd-inhibit.ts" = {
    source = ./extensions/systemd-inhibit.ts;
  };

  home.file."${piConfigDir}/agents/semble-search.md" = {
    source = ./semble-search.md;
  };

}
