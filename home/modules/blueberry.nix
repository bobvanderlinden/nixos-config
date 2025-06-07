{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
{
  options = {
    services.blueberry = {
      enable = mkEnableOption "" // {
        description = ''
          Whether to enable the blueberry applet.
          </para><para>
          Note, for the applet to work, the 'blueberry' service should
          be enabled system-wide. You can enable it in the system
          configuration using
          <programlisting language="nix">
            services.blueberry.enable = true;
          </programlisting>
        '';
      };
    };
  };

  config = mkIf config.services.blueberry.enable {
    home.packages = [ pkgs.blueberry ];
    systemd.user.services.blueberry = {
      Unit = {
        Description = "blueberry applet";
        # Avoid depencency cycle, resulting in waybar not starting.
        # Requires = [ "tray.target" ];
        After = [ "tray.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${pkgs.blueberry}/bin/blueberry";
      };
    };
  };
}
