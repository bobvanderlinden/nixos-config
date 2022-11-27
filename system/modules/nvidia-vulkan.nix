{ pkgs, config, lib, ... }:
with lib;
let
  openglVulkanDrivers = mesa:
    (mesa.overrideAttrs (oldAttrs: {
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ pkgs.glslang ];
      mesonFlags = oldAttrs.mesonFlags ++ [ "-Dvulkan-layers=device-select,overlay" ];
      patches = oldAttrs.patches ++ [ ./mesa-vulkan-layer-nvidia.patch ];
      postInstall = ''
        ${oldAttrs.postInstall}

        mv $out/lib/libVkLayer* $drivers/lib

        #Device Select layer
        layer=VkLayer_MESA_device_select
        substituteInPlace $drivers/share/vulkan/implicit_layer.d/''${layer}.json \
          --replace "lib''${layer}" "$drivers/lib/lib''${layer}"

        #Overlay layer
        layer=VkLayer_MESA_overlay
        substituteInPlace $drivers/share/vulkan/explicit_layer.d/''${layer}.json \
          --replace "lib''${layer}" "$drivers/lib/lib''${layer}"
      '';
    })).drivers;
in
{
  options.hardware.nvidia.vulkan.enable = mkEnableOption "nvidia vulkan support";

  config = mkIf config.hardware.nvidia.vulkan.enable {
    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.vulkan_beta;
    hardware.nvidia.modesetting.enable = true;

    # Chromium cannot find libvulkan.so.1
    environment.sessionVariables.LD_LIBRARY_PATH = "${pkgs.vulkan-loader}/lib";

    # Source: https://nixos.wiki/wiki/Mesa
    hardware.opengl =
      {
        enable = true;
        driSupport = true;
        driSupport32Bit = true;
        package = openglVulkanDrivers pkgs.mesa;
        package32 = openglVulkanDrivers pkgs.pkgsi686Linux.mesa;
      };
  };
}
