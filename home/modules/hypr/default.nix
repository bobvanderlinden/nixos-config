{
  impurity,
  pkgs,
  ...
}:
let
  # hypr-once <name> <command> [args...]
  # Launches <command> once and holds a per-session lock for its lifetime, so
  # re-invocations (e.g. when `hyprctl reload` re-runs the start hook) become
  # no-ops instead of spawning duplicates. Replaces graphical-session.target
  # autostart for apps started from hyprland.lua.
  hypr-once = pkgs.writeShellApplication {
    name = "hypr-once";
    runtimeInputs = [ pkgs.util-linux ];
    text = ''
      name=$1
      shift
      exec flock --nonblock "''${XDG_RUNTIME_DIR:-/run/user/$(id --user)}/hypr-once-$name.lock" "$@"
    '';
  };
in
{
  home.packages = [
    hypr-once
  ]
  ++ (with pkgs; [
    jq
    wl-screenrecord
  ]);

  xdg.configFile."hypr/hyprland.lua".source = impurity.link ./hyprland.lua;
}
