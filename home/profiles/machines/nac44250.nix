{ lib, ... }:
{
  # This panel uses 2x logical scaling. The bottom 70 logical pixels have
  # display artifacts, so keep tiled windows out of that area.
  wayland.windowManager.hyprland.extraLuaFiles.monitor = ''
    hl.monitor({
      output = "eDP-1",
      scale = 2,
      reserved = { bottom = 70 },
    })
  '';

  systemd.user.services.quickshell.Service.Environment = lib.mkForce [
    "QUICKSHELL_BAR_EDGE=top"
  ];
}
