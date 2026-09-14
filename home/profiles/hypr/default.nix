{
  impurity,
  pkgs,
  ...
}:
{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    plugins = [ pkgs.scrolloverview ];
    extraLuaFiles.config = impurity.link ./hyprland.lua;
  };

  home.packages = with pkgs; [ jq ];

  xdg.configFile = {
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
