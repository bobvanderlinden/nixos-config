{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.xdg-desktop-portal-hyprland;
in
{
  options.services.xdg-desktop-portal-hyprland = {
    enable = lib.mkEnableOption "XDG Desktop Portal Hyprland implementation";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.xdg-desktop-portal-hyprland;
      description = "The xdg-desktop-portal-hyprland package to use.";
    };
    target = lib.mkOption {
      type = lib.types.str;
      default = "graphical-session.target";
      example = "hyprland-session.target";
      description = "The systemd target to bind to.";
    };
    settings = lib.mkOption {
      type =
        with lib.types;
        let
          valueType =
            nullOr (oneOf [
              bool
              int
              float
              str
              path
              (attrsOf valueType)
              (listOf valueType)
            ])
            // {
              description = "Hyprland configuration value";
            };
        in
        valueType;
      default = { };
      description = "Settings for the hyprland portal.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xdg-desktop-portal.portals = [ cfg.package ];

    xdg.configFile."hypr/xdph.conf".text = lib.hm.generators.toHyprconf {
      attrs = cfg.settings;
    };

    systemd.user.services.xdg-desktop-portal-hyprland = {
      Unit = {
        Description = "Portal service (Hyprland implementation)";
        PartOf = [ cfg.target ];
        After = [ cfg.target ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        Type = "dbus";
        BusName = "org.freedesktop.impl.portal.desktop.hyprland";
        ExecStart = "${cfg.package}/libexec/xdg-desktop-portal-hyprland";
        Restart = "on-failure";
        Slice = "session.slice";
      };
    };
  };
}
