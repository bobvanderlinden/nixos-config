{ pkgs
, config
, inputs
, ...
}: {
  imports = with inputs.nixos-hardware.nixosModules; [
    # common-cpu-intel
    # common-gpu-nvidia
    common-pc-laptop-ssd
    common-pc-laptop
  ];

  # Replacement for common-cpu-intel
  # boot.initrd.kernelModules = [ "i915" ];
  # hardware.cpu.intel.updateMicrocode = config.hardware.enableRedistributableFirmware;

  # Replacement for common-gpu-nvidia
  services.xserver.videoDrivers = [ "nvidia" ];

  # Currently the stable and production versions of nvidiaPackages are crashing X11. beta does not.
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.beta;

  # The latest nvidia versions result in 2 different backlight services.
  # This interferes with brightnessctl, that increases/decreases brightness too much.
  boot.kernelParams = [
    "acpi_backlight=vendor"
    "video.use_native_backlight=1"
  ];

  # nixos-hardware defaults to va_gl for intel chipsets.
  # This breaks on systems with nvidia.
  # See https://github.com/NixOS/nixos-hardware/issues/388
  environment.variables.VDPAU_DRIVER = "nvidia";

  hardware.nvidia.powerManagement.enable = true;
  hardware.enableRedistributableFirmware = true;
}
