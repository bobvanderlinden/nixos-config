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
      PartOf = [ "hyprland-session.target" ];
      After = [ "hyprland-session.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe' pkgs.hyprland "hyprctl"} plugin load ${pkgs.scrolloverview}/lib/libscrolloverview.so";
      ExecStartPost = "${lib.getExe' pkgs.hyprland "hyprctl"} reload";
    };

    Install.WantedBy = [ "hyprland-session.target" ];
  };
  home.packages = with pkgs; [ jq ];

  systemd.user.targets.hyprland-session = {
    Unit = {
      Description = "Hyprland compositor session";
      BindsTo = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
      After = [ "graphical-session-pre.target" ];
      PropagatesStopTo = [ "graphical-session.target" ];
    };
  };

  xdg.configFile."hypr/hyprland.lua".source = impurity.link ./hyprland.lua;
}
