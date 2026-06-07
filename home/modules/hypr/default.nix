{
  config,
  impurity,
  lib,
  pkgs,
  ...
}:
let
  screencopy-picker = pkgs.writeShellApplication {
    name = "screencopy-picker";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.jq
    ];
    text = ''
      echo "[SELECTION]/screen:$(hyprctl activeworkspace -j | jq --raw-output .monitor)"
    '';
  };

  xdphConfig = pkgs.writeText "xdph.conf" (
    lib.hm.generators.toHyprconf {
      attrs = {
        screencopy.custom_picker_binary = "${screencopy-picker}/bin/screencopy-picker";
      };
    }
  );
in
{
  home.packages = with pkgs; [
    jq
    wl-screenrecord
  ];

  xdg.configFile."hypr/hyprland.lua".source = impurity.link ./hyprland.lua;
}
