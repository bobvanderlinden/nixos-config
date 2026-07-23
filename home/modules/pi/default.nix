{
  config,
  lib,
  pkgs,
  ...
}:
let
  piConfigDir = config.programs.pi-coding-agent.configDir;

  extensionFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".ts" name) (
    builtins.readDir ./extensions
  );
  extensionFileLinks = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "${piConfigDir}/extensions/${name}" {
      source = ./extensions + "/${name}";
    }
  ) extensionFiles;
in
{
  imports = [ ./semble.nix ];

  programs.pi-coding-agent = {
    enable = true;
    package = pkgs.pi-coding-agent;

    extraPackages = [
      pkgs.nodejs
      pkgs.git
      pkgs.direnv
      pkgs.systemd
      pkgs.hyprland
      pkgs.coin
      pkgs.hypr-notify
    ];

    settings = {
      lastChangelogVersion = "0.80.2";
      collapseChangelog = true;
      enableAnalytics = false;
      enableInstallTelemetry = false;
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
    '';
  };

  home.packages = [ pkgs.nodejs ];

  home.file = extensionFileLinks;
}
