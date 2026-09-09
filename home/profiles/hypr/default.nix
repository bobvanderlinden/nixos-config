{
  impurity,
  lib,
  pkgs,
  ...
}:
{
  systemd.user.services.scrolloverview = {
    Unit = {
      Description = "Load the ScrollOverview Hyprland plugin";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe' pkgs.hyprland "hyprctl"} plugin load ${pkgs.scrolloverview}/lib/libscrolloverview.so";
      ExecStartPost = "${lib.getExe' pkgs.hyprland "hyprctl"} reload";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
  home.packages = with pkgs; [ jq ];

  xdg.configFile = {
    "hypr/hyprland.lua".source = impurity.link ./hyprland.lua;
    "uwsm/env".text = ''
      export BROWSER=chromium
      export EDITOR="code --wait"
      export ELECTRON_OZONE_PLATFORM_HINT=wayland
      export SDL_VIDEODRIVER=wayland
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
      export _JAVA_AWT_WM_NONREPARENTING=1
      export CLUTTER_BACKEND=wayland
      export MOZ_DISABLE_RDD_SANDBOX=1
      export NIXOS_OZONE_WL=1
      export LIBVA_DRIVER_NAME=nvidia
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export NVD_BACKEND=direct
    '';
  };
}
