{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.hardware.v4l2loopback;
in {
  options.hardware.v4l2loopback = {
    enable = mkEnableOption "Enable the confguration to use the reflex as a webcam";
  };

  config = mkIf cfg.enable {
    boot.extraModulePackages = [
      config.boot.kernelPackages.v4l2loopback
    ];

    boot.kernelModules = [
      "v4l2loopback"
    ];
  };
}
