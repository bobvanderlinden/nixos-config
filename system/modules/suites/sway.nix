{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkDefault mkIf;
in
{
  options = {
    suites.sway = {
      enable = mkEnableOption "sway suite";
    };
  };

  config =
    let
      cfg = config.suites.sway;
      backgroundColor = "1a1b26";
      wallpaperSvg = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nix-snowflake.svg";
        hash = "sha256-SCuQlSPB14GFTq4XvExJ0QEuK2VIbrd5YYKHLRG/q5I=";
      };
      wallpaperPng = pkgs.runCommand "nix-snowflake.png" { } ''
        ${pkgs.resvg}/bin/resvg ${wallpaperSvg} $out
      '';
    in
    mkIf cfg.enable {
      suites.wayland.enable = mkDefault true;

      services.displayManager.defaultSession = mkDefault "sway";

      security.pam.services.swaylock = {
        fprintAuth = true;
      };

      home-manager.sharedModules = [
        (
          { config, ... }:
          {
            xdg.portal = {
              enable = true;
              config.sway = {
                default = [
                  "gtk"
                  "wlr"
                  "gnome"
                ];

                # Source: https://gitlab.archlinux.org/archlinux/packaging/packages/sway/-/commit/87acbcfcc8ea6a75e69ba7b0c976108d8e54855b
                "org.freedesktop.impl.portal.Inhibit" = "none";

                # See https://github.com/NixOS/nixpkgs/issues/262286#issuecomment-2495558476

                # wlr interfaces
                "org.freedesktop.impl.portal.ScreenCast" = "wlr";
                "org.freedesktop.impl.portal.Screenshot" = "wlr";

                # gnome-keyring interfaces
                "org.freedesktop.impl.portal.Secret" = "gnome-keyring";

                "org.freedesktop.impl.portal.Settings" = "darkman";

                # GTK interfaces
                "org.freedesktop.impl.portal.FileChooser" = "gtk";
                "org.freedesktop.impl.portal.AppChooser" = "gtk";
                "org.freedesktop.impl.portal.Print" = "gtk";
                "org.freedesktop.impl.portal.Notification" = "gtk";
                # "org.freedesktop.impl.portal.Inhibit" = "gtk";
                "org.freedesktop.impl.portal.Access" = "gtk";
                "org.freedesktop.impl.portal.Account" = "gtk";
                "org.freedesktop.impl.portal.Email" = "gtk";
                "org.freedesktop.impl.portal.DynamicLauncher" = "gtk";
                "org.freedesktop.impl.portal.Lockdown" = "gtk";
                # "org.freedesktop.impl.portal.Settings" = "gtk";
                "org.freedesktop.impl.portal.Wallpaper" = "gtk";

                # Gnome interfaces
                # "org.freedesktop.impl.portal.Access" = "gnome";
                # "org.freedesktop.impl.portal.Account" = "gnome";
                # "org.freedesktop.impl.portal.AppChooser" = "gnome";
                "org.freedesktop.impl.portal.Background" = "gnome";
                "org.freedesktop.impl.portal.Clipboard" = "gnome";
                # "org.freedesktop.impl.portal.DynamicLauncher" = "gnome";
                # "org.freedesktop.impl.portal.FileChooser" = "gnome";
                "org.freedesktop.impl.portal.InputCapture" = "gnome";
                # "org.freedesktop.impl.portal.Lockdown" = "gnome";
                # "org.freedesktop.impl.portal.Notification" = "gnome";
                # "org.freedesktop.impl.portal.Print" = "gnome";
                "org.freedesktop.impl.portal.RemoteDesktop" = "gnome";
                # "org.freedesktop.impl.portal.ScreenCast" = "gnome";
                # "org.freedesktop.impl.portal.Screenshot" = "gnome";
                # "org.freedesktop.impl.portal.Settings" = "gnome";
                # "org.freedesktop.impl.portal.Wallpaper" = "gnome";
              };
              extraPortals = with pkgs; [
                xdg-desktop-portal-wlr
                xdg-desktop-portal-gtk
                xdg-desktop-portal-gnome
                gnome-keyring
                darkman
              ];
              configPackages = with pkgs; [
                gnome-session
                gnome-keyring
              ];
            };

            xdg.configFile."xdg-desktop-portal-wlr/sway".text = ''
              [screencast]
              output_name=eDP-1
              chooser_type=none
            '';

            home.pointerCursor.sway.enable = true;

            i18n.inputMethod = {
              enable = true;
              type = "fcitx5";
            };

            home.packages = [
              pkgs.wl-screenrecord
              pkgs.wl-screenshot
              pkgs.seahorse
            ];

            wayland.windowManager.sway = {
              enable = true;
              wrapperFeatures.gtk = true;
              systemd = {
                enable = true;
                xdgAutostart = true;
              };
              xwayland = true;
              config = {
                modifier = "Mod4";
                input = {
                  "*" = {
                    tap = "enabled";
                  };
                };
                bars = [
                  {
                    command = "waybar";
                    position = "bottom";
                  }
                ];
                keybindings =
                  let
                    swayosd_client = "${config.services.swayosd.package}/bin/swayosd-client";
                    mod = config.wayland.windowManager.sway.config.modifier;
                  in
                  {
                    "${mod}+t" = "exec kitty";
                    "${mod}+w" = "exec chromium";
                    "${mod}+e" = "exec thunar";
                    "${mod}+q" = "exec ${pkgs.wofi}/bin/wofi --show run";
                    "${mod}+Delete" = "exec loginctl lock-session";
                    "${mod}+Print" = "exec flameshot gui";
                    "${mod}+Shift+Print" = "exec wl-screenrecord";
                    "${mod}+c" = "kill";

                    "${mod}+Shift+grave" = "move scratchpad";
                    "${mod}+grave" = "scratchpad show";
                    "${mod}+j" = "focus left";
                    "${mod}+k" = "focus down";
                    "${mod}+l" = "focus up";
                    "${mod}+semicolon" = "focus right";
                    "${mod}+Left" = "focus left";
                    "${mod}+Down" = "focus down";
                    "${mod}+Up" = "focus up";
                    "${mod}+Right" = "focus right";
                    "${mod}+Shift+j" = "move left";
                    "${mod}+Shift+k" = "move down";
                    "${mod}+Shift+l" = "move up";
                    "${mod}+Shift+semicolon" = "move right";
                    "${mod}+Shift+Left" = "move left";
                    "${mod}+Shift+Down" = "move down";
                    "${mod}+Shift+Up" = "move up";
                    "${mod}+Shift+Right" = "move right";
                    "${mod}+Ctrl+Left" = "resize grow left";
                    "${mod}+Ctrl+Down" = "resize grow down";
                    "${mod}+Ctrl+Up" = "resize grow up";
                    "${mod}+Ctrl+Right" = "resize grow right";
                    "${mod}+h" = "splith";
                    "${mod}+v" = "splitv";
                    "${mod}+f" = "fullscreen";
                    "${mod}+Shift+s" = "layout stacking";
                    "${mod}+Shift+t" = "layout tabbed";
                    "${mod}+Shift+g" = "sticky toggle";
                    "${mod}+Shift+f" = "floating toggle";
                    "${mod}+space" = "focus mode_toggle";
                    "${mod}+1" = "workspace 1";
                    "${mod}+2" = "workspace 2";
                    "${mod}+3" = "workspace 3";
                    "${mod}+4" = "workspace 4";
                    "${mod}+5" = "workspace 5";
                    "${mod}+6" = "workspace 6";
                    "${mod}+7" = "workspace 7";
                    "${mod}+8" = "workspace 8";
                    "${mod}+9" = "workspace 9";
                    "${mod}+0" = "workspace 10";
                    "${mod}+Shift+1" = "move container to workspace 1";
                    "${mod}+Shift+2" = "move container to workspace 2";
                    "${mod}+Shift+3" = "move container to workspace 3";
                    "${mod}+Shift+4" = "move container to workspace 4";
                    "${mod}+Shift+5" = "move container to workspace 5";
                    "${mod}+Shift+6" = "move container to workspace 6";
                    "${mod}+Shift+7" = "move container to workspace 7";
                    "${mod}+Shift+8" = "move container to workspace 8";
                    "${mod}+Shift+9" = "move container to workspace 9";
                    "${mod}+Shift+0" = "move container to workspace 10";
                    "${mod}+Control+Shift+Right" = "move workspace to output right";
                    "${mod}+Control+Shift+Left" = "move workspace to output left";
                    "${mod}+Control+Shift+Up" = "move workspace to output up";
                    "${mod}+Control+Shift+Down" = "move workspace to output down";
                    "${mod}+Shift+r" = "restart";

                    "XF86AudioRaiseVolume" = "exec ${swayosd_client} --output-volume raise";
                    "XF86AudioLowerVolume" = "exec ${swayosd_client} --output-volume lower";
                    "XF86AudioMute" = "exec ${swayosd_client} --output-volume mute-toggle";

                    "XF86MonBrightnessUp" = "exec ${swayosd_client} --brightness raise";
                    "XF86MonBrightnessDown" = "exec ${swayosd_client} --brightness lower";

                    "XF86AudioPlay" = "exec ${pkgs.playerctl}/bin/playerctl play";
                    "XF86AudioPause" = "exec ${pkgs.playerctl}/bin/playerctl pause";
                    "XF86AudioNext" = "exec ${pkgs.playerctl}/bin/playerctl next";
                    "XF86AudioPrev" = "exec ${pkgs.playerctl}/bin/playerctl previous";
                  };

                startup = [
                  # Auto-start all *.desktop files in auto-start directories.
                  { command = "${pkgs.dex}/bin/dex -a"; }
                  { command = "nm-applet --indicator"; }
                ];
              };
              extraConfig = ''
                swaybg_command ${pkgs.swaybg}/bin/swaybg --mode center --color '#${backgroundColor}' --image ${wallpaperPng}

                default_orientation horizontal
                workspace_layout tabbed

                for_window [app_id="Bitwarden"] move scratchpad
                for_window [app_id="Bitwarden"] sticky enable
                for_window [class="gnome-pomodoro"] move scratchpad
                for_window [class="gnome-pomodoro"] sticky enable
                for_window [class="floating"] floating enable

                for_window [window_type="dialog"] floating enable
                for_window [window_type="utility"] floating enable
                for_window [window_type="toolbar"] floating enable
                for_window [window_type="splash"] floating enable
                for_window [window_type="menu"] floating enable
                for_window [window_type="dropdown_menu"] floating enable
                for_window [window_type="popup_menu"] floating enable
                for_window [window_type="tooltip"] floating enable
                for_window [window_type="notification"] floating enable/

                # Based on https://www.reddit.com/r/swaywm/comments/l9asbc/comment/h4pwfb4/
                for_window [app_id="Zoom"] floating enable, sticky enable
                for_window [app_id="Zoom" title="Zoom Meeting"] inhibit_idle open

                for_window [app_id="Zoom" title="as_toolbar"] floating enable, sticky enable
                for_window [app_id="Zoom" title="^(Zoom|About)$"] border pixel
                for_window [app_id="Zoom" title="Settings"] floating_minimum_size 200 x 200
                for_window [class="zoom"] floating enable
              '';
            };

            programs.swaylock = {
              enable = true;
              package = pkgs.swaylock-fprintd;
              settings = {
                color = backgroundColor;
                scaling = "center";
                image = "${wallpaperPng}";
              };
            };

            services.swayosd.enable = true;

            services.swayidle =
              let
                swaylock = config.programs.swaylock.package;
              in
              {
                enable = true;
                package = pkgs.swayidle.overrideAttrs (oldAttrs: {
                  patches = [
                    # Support for org.freedesktop.ScreenSaver
                    # Needed to avoid locking screen while video-calling in Zoom
                    # See https://github.com/swaywm/swayidle/pull/164
                    (pkgs.fetchpatch {
                      url = "https://github.com/bobvanderlinden/swayidle/compare/f554943b..f7ba70e5.patch";
                      hash = "sha256-ff7Ffd1fl6wRWK8XQW21Pybivv7XhtHhoV2P8pBE+ts=";
                    })
                  ];
                });
                timeouts = [
                  {
                    timeout = 5 * 60;
                    command = "${swaylock}/bin/swaylock --daemonize --fingerprint";
                  }
                ];
                events = [
                  {
                    event = "before-sleep";
                    command = "${swaylock}/bin/swaylock --daemonize --fingerprint";
                  }
                  {
                    event = "lock";
                    command = "${swaylock}/bin/swaylock --daemonize --fingerprint";
                  }
                ];
              };

            programs.waybar = {
              enable = true;
              style =
                let
                  # base16-default-dark-css = pkgs.fetchurl {
                  #   url = "https://raw.githubusercontent.com/mnussbaum/base16-waybar/d2f943b1abb9c9f295e4c6760b7bdfc2125171d2/colors/base16-default-dark.css";
                  #   hash = "sha256:1dncxqgf7zsk39bbvrlnh89lsgr2fnvq5l50xvmpnibk764bz0jb";
                  # };
                  style = pkgs.fetchurl {
                    url = "https://raw.githubusercontent.com/robertjk/dotfiles/253b86442dae4d07d872e8b963fa33b5f8819594/.config/waybar/style.css";
                    hash = "sha256-7bEOPMslgpXsKOa2aMqVoV5z1OSSRqXs2UGDgWwejx4=";
                  };
                in
                ''
                  @import "${style}";
                '';
              settings = {
                mainBar = {
                  position = "bottom";
                  modules-left = [
                    "sway/workspaces"
                    "sway/mode"
                  ];
                  modules-center = [ ];
                  modules-right = [
                    "network"
                    "battery"
                    "clock"
                    "tray"
                  ];
                  "sway/workspaces" = {
                    enable-bar-scroll = true;
                  };
                  "sway/window" = {
                    max-length = 50;
                  };
                  network = {
                    format = "";
                    format-wired = "";
                    format-linked = "";
                    format-wifi = "{essid} {icon}";
                    format-disconnected = "";
                    tooltip-format = "{ifname}\n{ipaddr}\n{essid} ({signalStrength}%)";
                  };
                  battery = {
                    format = "{capacity}% {icon}";
                    format-icons = [
                      ""
                      ""
                      ""
                      ""
                      ""
                    ];
                    format-charging = "<span font='Font Awesome 5 Free'></span>  <span font='Font Awesome 5 Free 11'>{icon}</span>  {capacity}% - {time}";
                    format-full = "<span font='Font Awesome 5 Free'></span>  <span font='Font Awesome 5 Free 11'>{icon}</span>  Charged";
                  };
                  clock = {
                    format-alt = "{:%a, %d. %b  %H:%M}";
                  };
                };
              };
            };

            programs.kitty = {
              enable = true;
            };

            programs.foot = {
              enable = false;
              server.enable = false;
              settings = {
                main = {
                  font = "monospace:size=12";
                };
                key-bindings = {
                  search-start = "Control+Shift+f";
                };
                search-bindings = {
                  find-next = "Control+f";
                  find-prev = "Control+Shift+f";
                  cursor-right = "none";
                };
              };
            };

            services.swaync = {
              enable = true;
              settings = {
                positionX = "right";
                positionY = "bottom";
                layer = "overlay";
              };
            };
          }
        )
      ];
    };
}
