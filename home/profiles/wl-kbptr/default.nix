{
  pkgs,
  ...
}:
let
  wl-kbptr-toggle = pkgs.writeShellApplication {
    name = "wl-kbptr-toggle";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.procps
      pkgs.wl-kbptr
      pkgs.ydotool
    ];
    text = ''
      if pkill --exact wl-kbptr; then
        exit 0
      fi

      result=$(wl-kbptr --only-print)
      if [[ -z "$result" ]]; then
        exit 0
      fi

      if [[ ! "$result" =~ ^([0-9]+)x([0-9]+)\+(-?[0-9]+)\+(-?[0-9]+)[[:space:]]+\+(-?[0-9]+)\+(-?[0-9]+)[[:space:]]+[lmrn]$ ]]; then
        printf 'wl-kbptr returned an unexpected result: %s\n' "$result" >&2
        exit 1
      fi

      x=$((BASH_REMATCH[3] + BASH_REMATCH[1] / 2 + BASH_REMATCH[5]))
      y=$((BASH_REMATCH[4] + BASH_REMATCH[2] / 2 + BASH_REMATCH[6]))
      hyprctl dispatch "hl.dsp.cursor.move({ x = $x, y = $y })"
      ydotool click 0xC0
    '';
  };
in
{
  programs.wl-kbptr = {
    enable = true;
    settings = {
      general.modes = "floating";
      mode_floating.source = "detect";
    };
  };

  home.packages = [ wl-kbptr-toggle ];

  xdg.configFile."hypr/conf.d/wl-kbptr.lua".source = ./wl-kbptr.lua;
}
