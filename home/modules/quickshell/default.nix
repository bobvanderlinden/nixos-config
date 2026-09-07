{
  lib,
  pkgs,
  impurity,
  ...
}:
{
  programs.quickshell = {
    enable = true;
    package = pkgs.quickshell;
    systemd.enable = false;
  };

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell desktop shell";
      PartOf = [ "hyprland-session.target" ];
      After = [ "hyprland-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };

    Service = {
      ExecStart = lib.getExe pkgs.quickshell;
      Restart = "on-failure";
      Slice = "session.slice";
    };

    Install.WantedBy = [ "hyprland-session.target" ];
  };

  # Additional binaries that the QML widgets call by name.
  home.packages = [
    pkgs.session-time
    pkgs.inotify-tools
    pkgs.todo-txt-cli
  ];

  home.file.".todo/config".text = ''
    TODO_DIR="$HOME/.todo"
    TODO_FILE="$TODO_DIR/todo.txt"
    DONE_FILE="$TODO_DIR/done.txt"
  '';

  # Symlink the entire quickshell source directory directly into XDG config.
  # Any edit to a .qml file is picked up by QuickShell's hot-reload immediately
  # without needing switch-home (when impurity is enabled).
  xdg.configFile."quickshell".source = impurity.link ./.;
}
