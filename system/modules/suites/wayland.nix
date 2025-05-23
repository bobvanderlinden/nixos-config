{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
{
  options.suites.wayland.enable = mkEnableOption "wayland";

  config = mkIf config.suites.wayland.enable {
    services.xserver.enable = mkDefault true;
    services.xserver.displayManager.gdm.wayland = mkDefault true;

    environment.systemPackages = [
      # Source: https://github.com/NixOS/nixpkgs/blob/45004c6f6330b1ff6f3d6c3a0ea8019f6c18a930/nixos/modules/programs/sway.nix#L47-L53
      pkgs.qt5.qtwayland
    ];

    environment.sessionVariables = {
      # Source: https://github.com/NixOS/nixpkgs/issues/271461#issuecomment-1934829672
      ELECTRON_OZONE_PLATFORM_HINT = "auto";

      # Source: https://github.com/NixOS/nixpkgs/blob/45004c6f6330b1ff6f3d6c3a0ea8019f6c18a930/nixos/modules/programs/sway.nix#L47-L53
      SDL_VIDEODRIVER = "wayland";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      _JAVA_AWT_WM_NONREPARENTING = "1";

      # Source: https://wiki.archlinux.org/title/Wayland#Clutter
      CLUTTER_BACKEND = "wayland";

      MOZ_DISABLE_RDD_SANDBOX = "1";
      EGL_PLATFORM = "wayland";
    };

    home-manager.sharedModules = [
      {
        home.packages = with pkgs; [ wlr-randr ];

        # Source: https://discourse.nixos.org/t/atril-is-blurry-engrampa-is-not-sway-scale-2/2865/2
        xresources.properties."Xft.dpi" = "96";

        # Make Chromium and Electron use Ozone Wayland support
        home.sessionVariables.NIXOS_OZONE_WL = "1";
      }
    ];
  };
}
