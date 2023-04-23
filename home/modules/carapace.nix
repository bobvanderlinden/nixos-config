{ config, lib, pkgs, ... }:
with lib;
let cfg = config.programs.carapace;
in {
  meta.maintainers = [ maintainers.bobvanderlinden ];

  options = {
    programs.carapace = {
      enable = mkEnableOption "carapace shell completion";

      package = mkOption {
        type = types.package;
        default = pkgs.carapace;
        defaultText = literalExpression "pkgs.carapace";
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

      enableNushellIntegration = mkOption {
        default = true;
        type = types.bool;
        description = ''
          Whether to enable Nushell integration.
        '';
      };
    };
  };
  config = mkIf cfg.enable
    {
      home.packages = [ cfg.package ];

      programs.bash.initExtra = mkIf cfg.enableBashIntegration ''
        source <(${cfg.package}/bin/carapace _carapace)
      '';

      programs.zsh.initExtra = mkIf cfg.enableZshIntegration ''
        eval (${cfg.package}/bin/carapace _carapace|slurp)
      '';

      programs.fish.shellInit = mkIf cfg.enableFishIntegration ''
        ${cfg.package}/bin/carapace _carapace | source
      '';

      programs.nushell.settingss =
        mkIf cfg.enableNushellIntegration
          {
            completions.external = {
              enable = true;
              completer.__nu = ''
                {|spans| 
                  carapace $spans.0 nushell $spans | from json
                }
              '';
            };
          };

      home.file = mkIf cfg.enableFishIntegration (
        # Convert the entries from `carapace --list` to
        # empty home.file.".config/fish/completions/NAME.fish"
        # entries.
        # This is to disable fish buildin completion for each of
        # the carapace-supported completions
        # It is in line with the instructions from carapace-bin:
        #
        #   carapace --list | awk '{print $1}' | xargs -I{} touch ~/.config/fish/completions/{}.fish
        #
        #  See https://github.com/rsteube/carapace-bin#getting-started
        let
          carapaceListFile = pkgs.runCommandLocal "carapace-list"
            {
              buildInputs = [ cfg.package ];
            } ''
            carapace --list > $out
          '';
        in
        lib.pipe carapaceListFile [
          lib.fileContents
          (lib.splitString "\n")
          (builtins.map (builtins.match "^([a-z0-9-]+) .*"))
          (builtins.filter (match: match != null && (builtins.length match) > 0))
          (builtins.map (match: builtins.head match))
          (builtins.map (name: {
            name = ".config/fish/completions/${name}.fish";
            value = {
              text = "";
            };
          }))
          builtins.listToAttrs
        ]
      );
    };
}
