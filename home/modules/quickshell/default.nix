{
  pkgs,
  impurity,
  ...
}:
{
  # Quickshell program via home-manager module.
  # The systemd user service is intentionally disabled: it races the Wayland
  # session at login and crashes ("no Qt platform plugin"). Quickshell is
  # launched from Hyprland instead (see home/modules/hypr/hyprland.lua).
  programs.quickshell = {
    enable = true;
    package = pkgs.quickshell;
    systemd.enable = false;
  };

  # Additional binaries that the QML widgets call by name.
  home.packages = [
    pkgs.session-time
    pkgs.inotify-tools
    pkgs.vja
  ];

  # Symlink the entire quickshell source directory directly into XDG config.
  # Any edit to a .qml file is picked up by QuickShell's hot-reload immediately
  # without needing switch-home (when impurity is enabled).
  xdg.configFile."quickshell".source = impurity.link ./.;
}
