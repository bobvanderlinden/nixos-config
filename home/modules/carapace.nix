{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.programs.carapace;
in
{
  options = {
    programs.carapace = {
      enable = mkEnableOption "carapace shell completion";

      package = mkOption {
        type = types.package;
        default = pkgs.carapace;
        defaultText = literalExample "pkgs.carapace";
        description = ''
          carapace package to use
        '';
      };

      enableBashIntegration = mkOption {
        default = true;
        type = types.bool;
        description = ''
          Whether to enable Bash integration.
        '';
      };

      enableZshIntegration = mkOption {
        default = true;
        type = types.bool;
        description = ''
          Whether to enable Zsh integration.
        '';
      };

      enableFishIntegration = mkOption {
        default = true;
        type = types.bool;
        description = ''
          Whether to enable Fish integration.
        '';
      };
    };
  };
  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    programs.bash.initExtra = mkIf cfg.enableBashIntegration ''
      source <(${cfg.package}/bin/carapace _carapace)
    '';

    programs.zsh.initExtra = mkIf cfg.enableZshIntegration ''
      eval (${cfg.package}/bin/carapace _carapace|slurp)
    '';

    programs.fish.shellInit = mkIf cfg.enableFishIntegration ''
      mkdir -p ~/.config/fish/completions
      ${cfg.package}/bin/carapace --list | awk '{print $1}' | xargs -I{} touch ~/.config/fish/completions/{}.fish # disable auto-loaded completions (#185)
      ${cfg.package}/bin/carapace _carapace | source
    '';
  };
}
