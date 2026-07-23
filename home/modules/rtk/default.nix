{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.rtk;
  piConfig = config.programs.pi-coding-agent;
  piConfigDir = piConfig.configDir;
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

    programs.pi-coding-agent.extraPackages = lib.mkIf piConfig.enable [ cfg.package ];

    xdg.configFile."rtk/config.toml" = lib.mkIf (cfg.settings != { }) {
      source = tomlFormat.generate "rtk-config.toml" cfg.settings;
    };

    home.file."${piConfigDir}/extensions/rtk.ts" = lib.mkIf piConfig.enable {
      source = cfg.package.src + "/hooks/pi/rtk.ts";
    };
  };
}
