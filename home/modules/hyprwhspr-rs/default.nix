{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hyprwhspr-rs;
in
{
  options.hyprwhspr-rs = {
    enable = lib.mkEnableOption "hyprwhspr-rs desktop dictation";

    package = lib.mkPackageOption pkgs "hyprwhspr-rs" { };

    settings = lib.mkOption {
      type =
        with lib.types;
        let
          valueType = nullOr (oneOf [
            bool
            int
            float
            str
            path
            (attrsOf valueType)
            (listOf valueType)
          ]);
        in
        attrsOf valueType;
      default = { };
      description = "Settings written to hyprwhspr-rs config.jsonc.";
    };

    hyprland = {
      enable = lib.mkEnableOption "Hyprland keybinding integration for hyprwhspr-rs";

      holdKey = lib.mkOption {
        type = lib.types.str;
        default = "$mod, V";
        example = "$mod ALT, D";
        description = "Hyprland keybinding prefix used for hold-to-talk recording with hyprwhspr-rs.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."hyprwhspr-rs/config.jsonc".text = builtins.toJSON cfg.settings;

    wayland.windowManager.hyprland.settings.bind = lib.mkIf cfg.hyprland.enable (
      lib.mkAfter [
        "${cfg.hyprland.holdKey}, exec, ${lib.getExe cfg.package} record start"
      ]
    );

    wayland.windowManager.hyprland.settings.bindr = lib.mkIf cfg.hyprland.enable (
      lib.mkAfter [
        "${cfg.hyprland.holdKey}, exec, ${lib.getExe cfg.package} record stop"
      ]
    );
  };
}
