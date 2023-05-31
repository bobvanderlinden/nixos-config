{ pkgs, config, lib, ... }:
let
  cfg = config.services.darkman;
  yamlFormat = pkgs.formats.yaml { };
in
{
  options.services.darkman = {
    enable = lib.mkEnableOption "darkman";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.darkman;
    };
    settings = lib.mkOption {
      type = yamlFormat.type;
    };
  };

  config = {
    home.packages = [ cfg.package ];

    systemd.user.services.darkman = {
      Unit = {
        Description = "Framework for dark-mode and light-mode transitions.";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };

      Service = {
        Type = "dbus";
        BusName = "nl.whynothugo.darkman";
        ExecStart = "${cfg.package}/bin/darkman run";
        Restart = "on-failure";
        TimeoutStopSec = "15";
        Slice = "background.slice";
        LockPersonality = "yes";
        RestrictNamespaces = "yes";
        SystemCallArchitectures = "native";
        SystemCallFilter = "@system-service @timer mincore";
        MemoryDenyWriteExecute = "yes";
      };
    };

    xdg.configFile = {
      "darkman/config.yaml" = {
        source = yamlFormat.generate "config.yaml" cfg.settings;
      };
    };

    xdg.dataFile = {
      "dark-mode.d/gtk-theme.sh" = {
        executable = true;
        text = ''
          ${pkgs.libnotify}/bin/notify-send --app-name="darkman" --urgency=low --icon=weather-clear-night "switching to dark mode"
          ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark
          ${pkgs.xfce.xfconf}/bin/xfconf-query -c xsettings -p /Net/ThemeName -s 'Adwaita-dark'
        '';
      };
      "light-mode.d/gtk-theme.sh" = {
        executable = true;
        text = ''
          ${pkgs.libnotify}/bin/notify-send --app-name="darkman" --urgency=low --icon=weather-clear "switching to light mode"
          ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface gtk-theme Adwaita
          ${pkgs.xfce.xfconf}/bin/xfconf-query -c xsettings -p /Net/ThemeName -s 'Adwaita'
        '';
      };
    };

    services.darkman.settings = {
      dbusserver = true;
      portal = true;
    };
  };
}
