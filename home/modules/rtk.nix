{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.rtk;
  tomlFormat = pkgs.formats.toml { };
in
{
  options.programs.rtk = {
    enable = lib.mkEnableOption "RTK token-efficient command-line tools";

    package = lib.mkPackageOption pkgs "rtk" { };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      example = {
        telemetry = {
          enabled = false;
        };
      };
      description = ''
        Settings written to {file}`$XDG_CONFIG_HOME/rtk/config.toml`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."rtk/config.toml" = lib.mkIf (cfg.settings != { }) {
      source = tomlFormat.generate "rtk-config.toml" cfg.settings;
    };
  };
}
