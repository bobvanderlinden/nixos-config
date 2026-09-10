{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.wl-kbptr;
  iniFormat = pkgs.formats.ini { };
in
{
  options.programs.wl-kbptr = {
    enable = lib.mkEnableOption "wl-kbptr keyboard pointer control";

    settings = lib.mkOption {
      type = iniFormat.type;
      default = { };
      example = {
        general.modes = "floating";
        mode_floating.source = "detect";
      };
      description = "Settings written to {file}`$XDG_CONFIG_HOME/wl-kbptr/config`.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Nixpkgs builds wl-kbptr with OpenCV enabled. `wl-kbptr --version`
    # reports `(opencv)`, and floating-mode detection requires it.
    home.packages = [ pkgs.wl-kbptr ];

    xdg.configFile."wl-kbptr/config".source = iniFormat.generate "wl-kbptr-config" cfg.settings;
  };
}
