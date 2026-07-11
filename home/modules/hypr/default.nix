{
  impurity,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    jq
    wl-screenrecord
  ];

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
