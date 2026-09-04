{
  config,
  lib,
  pkgs,
  ...
}:
{
  networking.hostName = "new-laptop";

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usbhid"
    "sd_mod"
  ];
  # Load the complete NVIDIA DRM stack before Plymouth starts. Without early
  # KMS, firmware often leaves the panel blank until the display manager runs.
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];
  boot.kernelModules = [ "nvidia" ];
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  hardware.enableAllFirmware = lib.mkForce false;
  hardware.enableRedistributableFirmware = lib.mkForce true;
  hardware.firmware = [ pkgs.linux-firmware ];

  # Lanzaboote generates keys after installation and enrolls them on the next
  # boot. That first boot is intentionally unsigned.
  boot.loader.systemd-boot.enable = false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    autoGenerateKeys.enable = true;
    autoEnrollKeys.enable = true;
  };
  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/boot/efi";
  };

  disko.devices = {
    disk.main = {
      type = "disk";
      # install-new-laptop replaces this through disko-install --disk.
      device = "/dev/disk/by-id/REPLACE-WITH-INSTALLER-DISK";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            label = "NIXOS-ESP";
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot/efi";
              mountOptions = [ "umask=0077" ];
            };
          };
          boot = {
            label = "NIXOS-BOOT";
            size = "2G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/boot";
            };
          };
          luks = {
            label = "NIXOS-LUKS";
            size = "100%";
            content = {
              type = "luks";
              name = "nixos";
              passwordFile = "/tmp/nixos-luks-password";
              settings.allowDiscards = true;
              extraOpenArgs = [ "--allow-discards" ];
              content = {
                type = "lvm_pv";
                vg = "nixos";
              };
            };
          };
        };
      };
    };

    lvm_vg.nixos = {
      type = "lvm_vg";
      lvs = {
        swap = {
          size = "SWAP_SIZE";
          content = {
            type = "swap";
            resumeDevice = true;
          };
        };
        root = {
          size = "100%FREE";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };

  system.stateVersion = "25.11";
}
