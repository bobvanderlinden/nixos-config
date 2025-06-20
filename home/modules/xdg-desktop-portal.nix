{
  config,
  lib,
  pkgs,
  ...
}:
# This is a replacement implementation for the xdg.portal module in home-manager.
# It automatically generates default portals based on the packages provided.
# It allows running xdg-desktop-portal in verbose mode, so it is possible to see any errors that might occur.
# It creates a portals directory in Nix, instead of in the user's profile directory. This avoids issues with packages in
# the profile, but not in the xdg-portal option being used as usable portals.
# It avoids using `home.sessionVariables`, which only applies to applications run from the shell and not those run from the compositor.
let
  cfg = config.services.xdg-desktop-portal;
  portalDir =
    pkgs.runCommand "xdg-desktop-portal-dir"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        env.PACKAGES = lib.escapeShellArgs cfg.portals;
      }
      ''
        function join_by { local IFS="$1"; shift; echo "$*"; }

        mkdir -p $out
        DEFAULT_PORTALS=()
        for package in $PACKAGES
        do
          for portal in "$package"/share/xdg-desktop-portal/portals/*.portal
          do
            DEFAULT_PORTALS+=("$(basename "$portal" .portal)")
            if [ ! -f $out/"$portal" ]; then
              ln -s "$portal" $out/
            fi
          done
        done
        echo "[preferred]" >> $out/portals.conf
        echo "default=$(join_by ';' "''${DEFAULT_PORTALS[@]}")" >> $out/portals.conf
      '';
in
{
  options.services.xdg-desktop-portal = {
    enable = lib.mkEnableOption "XDG Desktop Portal";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.xdg-desktop-portal;
      description = "The XDG Desktop Portal package to use.";
    };

    target = lib.mkOption {
      type = lib.types.str;
      default = "graphical-session.target";
      example = "hyprland-session.target";
      description = "The systemd target to bind to.";
    };

    verbose = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to run the XDG Desktop Portal in verbose mode.";
    };

    portals = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Packages that contain xdg portals. These packages should contain `/share/xdg-desktop-portal/portals/*.portal` files.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.xdg-desktop-portal = {
      Unit = {
        Description = "XDG Desktop Portal";
        PartOf = [ cfg.target ];
      };

      Service = {
        Type = "dbus";
        BusName = "org.freedesktop.portal.Desktop";
        ExecStart = "${cfg.package}/libexec/xdg-desktop-portal ${lib.optionalString cfg.verbose "--verbose"}";
        Slice = "session.slice";
        Restart = "on-failure";
        Environment = [
          "XDG_DESKTOP_PORTAL_DIR=${portalDir}"
        ];
      };
    };
  };
}
