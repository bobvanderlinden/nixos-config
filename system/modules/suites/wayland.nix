{ pkgs, config, lib, ... }:
with lib;
{
  options.suites.wayland.enable = mkEnableOption "wayland";

  config = mkIf config.suites.wayland.enable
    {
      hardware.nvidia.vulkan.enable = mkDefault true;

      services.xserver.enable = mkDefault true;
      systemd.services.display-manager.enable = mkDefault true;
      services.xserver.displayManager.gdm.wayland = mkDefault true;

      environment.systemPackages = [
        # Source: https://github.com/NixOS/nixpkgs/blob/45004c6f6330b1ff6f3d6c3a0ea8019f6c18a930/nixos/modules/programs/sway.nix#L47-L53
        pkgs.qt5.qtwayland
      ];

      environment.sessionVariables = {
        # Source: https://nixos.wiki/wiki/Slack#Wayland
        # Source: https://nixos.wiki/wiki/Visual_Studio_Code#Wayland
        NIXOS_OZONE_WL = "1";

        # Source: https://github.com/cole-mickens/nixcfg/blob/707b2db0a5f69ffda027f8008835f01d03954dcb/mixins/nvidia.nix#L7-L13
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";

        # Source: https://github.com/NixOS/nixpkgs/blob/45004c6f6330b1ff6f3d6c3a0ea8019f6c18a930/nixos/modules/programs/sway.nix#L47-L53
        SDL_VIDEODRIVER = "wayland";
        QT_QPA_PLATFORM = "wayland-egl";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        _JAVA_AWT_WM_NONREPARENTING = "1";

        # Source: https://wiki.archlinux.org/title/Wayland#Clutter
        CLUTTER_BACKEND = "wayland";
      };

      home-manager.sharedModules = [
        {
          home.packages = with pkgs; [
            swaylock
            wlr-randr
          ];

          # Source: https://discourse.nixos.org/t/atril-is-blurry-engrampa-is-not-sway-scale-2/2865/2
          xresources.properties."Xft.dpi" = "96";

          # Source: https://wiki.archlinux.org/title/Wayland#Configuration_file
          home.file.".config/electron-flags.conf".text = ''
            --enable-features=WaylandWindowDecorations
            --ozone-platform-hint=auto
          '';

          # Source: https://wiki.archlinux.org/title/Wayland#Older_Electron_versions
          home.file.".config/electron13-flags.conf".text = ''
            --enable-features=UseOzonePlatform
            --ozone-platform=wayland
          '';
        }
      ];
    };
}
