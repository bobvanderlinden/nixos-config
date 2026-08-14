{
  config,
  impurity,
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
      source = impurity.link (./extensions + "/${name}");
    }
  ) extensionFiles;

  skillFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) (
    builtins.readDir ./skills
  );
  skillFileLinks = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "${piConfigDir}/skills/${name}" {
      source = impurity.link (./skills + "/${name}");
    }
  ) skillFiles;
in
{
  home.file = extensionFileLinks // skillFileLinks;

  imports = [ ./mcp.nix ];

  programs.pi-coding-agent = {
    enable = true;
    enableMcpIntegration = lib.mkDefault true;
    mcp.enable = lib.mkDefault true;
    package = pkgs.pi;

    extraPackages = [
      pkgs.nodejs
      pkgs.git
      pkgs.ripgrep
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
      defaultProvider = "openai-codex";
      defaultModel = "gpt-5.6-terra";
      defaultThinkingLevel = "medium";
      npmCommand = [ "${pkgs.nodejs}/bin/npm" ];
      packages = [
        "npm:pi-subagents"
        "npm:pi-web-access"
        "npm:@ayulab/pi-rewind"
        "pi-lens"
      ];
    };

    context = impurity.link ./AGENTS.md;

  };
}
