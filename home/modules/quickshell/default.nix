{
  pkgs,
  impurity,
  ...
}:
{
  # Quickshell program + systemd service via home-manager module.
  programs.quickshell = {
    enable = true;
    package = pkgs.quickshell;
    systemd.enable = true;
    # target defaults to config.wayland.systemd.target (hyprland-session.target)
  };

  # Additional binaries that the QML widgets call by name.
  home.packages = [
    pkgs.session-time
    pkgs.inotify-tools
  ];

  # Symlink the entire quickshell source directory directly into XDG config.
  # Any edit to a .qml file is picked up by QuickShell's hot-reload immediately
  # without needing switch-home (when impurity is enabled).
  xdg.configFile."quickshell".source = impurity.link ./.;
}
