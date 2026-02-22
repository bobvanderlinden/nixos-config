{
  pkgs,
  config,
  lib,
  ...
}:
let
  # Absolute path to the quickshell source directory in the repo.
  # Using a literal path so mkOutOfStoreSymlink points to the live working copy,
  # enabling QuickShell hot-reload on file edits without switch-home.
  srcDir = "/home/bob.vanderlinden/projects/nixos-config/home/modules/quickshell";

  # docker-count script — added to home.packages so it's on PATH.
  docker-count = pkgs.writeShellApplication {
    name = "docker-count";
    text = ''
      docker ps --format json | jq --slurp 'length'
    '';
    runtimeInputs = [
      pkgs.docker
      pkgs.jq
    ];
  };

  # Helper to symlink a file from the source tree directly.
  src = filename: config.lib.file.mkOutOfStoreSymlink "${srcDir}/${filename}";
in
{
  # Install quickshell and the binaries that the QML widgets call by name.
  home.packages = [
    pkgs.quickshell
    pkgs.session-time
    pkgs.inotify-tools
    config.programs.voxtype.package
    docker-count
  ];

  # Deploy all QML sources as symlinks to the live repo working tree.
  # Any edit to a .qml file is picked up by QuickShell's hot-reload immediately.
  xdg.configFile."quickshell/shell.qml".source = src "shell.qml";
  xdg.configFile."quickshell/AgentState.qml".source = src "AgentState.qml";
  xdg.configFile."quickshell/StatusBar.qml".source = src "StatusBar.qml";
  xdg.configFile."quickshell/NotificationPopup.qml".source = src "NotificationPopup.qml";
  xdg.configFile."quickshell/WorkspacesWidget.qml".source = src "WorkspacesWidget.qml";
  xdg.configFile."quickshell/AgentsWidget.qml".source = src "AgentsWidget.qml";
  xdg.configFile."quickshell/SystemdFailedUnits.qml".source = src "SystemdFailedUnits.qml";
  xdg.configFile."quickshell/DockerWidget.qml".source = src "DockerWidget.qml";
  xdg.configFile."quickshell/SessionTimeWidget.qml".source = src "SessionTimeWidget.qml";
  xdg.configFile."quickshell/VoxtypeWidget.qml".source = src "VoxtypeWidget.qml";
  xdg.configFile."quickshell/NetworkWidget.qml".source = src "NetworkWidget.qml";
  xdg.configFile."quickshell/BatteryWidget.qml".source = src "BatteryWidget.qml";
  xdg.configFile."quickshell/VolumeWidget.qml".source = src "VolumeWidget.qml";
  xdg.configFile."quickshell/ClockWidget.qml".source = src "ClockWidget.qml";
  xdg.configFile."quickshell/TrayWidget.qml".source = src "TrayWidget.qml";

  # Systemd user service for quickshell.
  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell desktop shell";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
      RestartSec = "2s";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
