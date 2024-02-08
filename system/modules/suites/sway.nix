{ config
, lib
, pkgs
, ...
}:
with lib; {
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
        ${pkgs.resvg}/bin/resvg --width 1920 --height 1080 ${wallpaperSvg} $out
      '';
    in
    mkIf cfg.enable {
      suites.wayland.enable = mkDefault true;

      services.xserver.displayManager.defaultSession = mkDefault "sway";

      security.pam.services.swaylock = {
        fprintAuth = true;
      };

      home-manager.sharedModules = [
        ({ config, ... }:
        {
          services.kanshi.enable = true;
          xdg.portal = {
            enable = true;
            # xdgOpenUsePortal = true;
            config.common = {
              default = [
                "wlr"
                "gtk"
                "gnome"
              ];
              "org.freedesktop.impl.portal.Secret" = [
                "gnome-keyring"
              ];
            };
            extraPortals = [
              pkgs.xdg-desktop-portal-wlr
              pkgs.xdg-desktop-portal-gtk
              pkgs.xdg-desktop-portal-gnome
            ];
            configPackages = [
              pkgs.gnome.gnome-session
              pkgs.gnome.gnome-keyring
            ];
          };

          services.gnome-keyring.enable = true;

          home.packages = [
            pkgs.gnome.seahorse
          ];


          wayland.windowManager.sway = rec {
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
                  swayosd = "${pkgs.swayosd}/bin/swayosd-client";
                  mod = config.modifier;
                in
                {
                  "${mod}+t" = "exec foot";
                  "${mod}+w" = "exec chromium";
                  "${mod}+e" = "exec thunar";
                  "${mod}+q" = "exec ${pkgs.wofi}/bin/wofi --show run";
                  "${mod}+Delete" = "exec loginctl lock-session";
                  "${mod}+Print" = "exec flameshot gui";
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
                  "${mod}+Shift+r" = "restart";
                  "${mod}+Shift+e" = ''
                    exec "i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3? This will end your X session.' -b 'Yes, exit i3' 'i3-msg exit'"
                  '';

                  "XF86AudioRaiseVolume" = "exec ${swayosd} --output-volume raise";
                  "XF86AudioLowerVolume" = "exec ${swayosd} --output-volume lower";
                  "XF86AudioMute" = "exec ${swayosd} --output-volume mute-toggle";

                  "XF86MonBrightnessUp" = "exec ${swayosd} --brightness raise";
                  "XF86MonBrightnessDown" = "exec ${swayosd} --brightness lower";

                  "XF86AudioPlay" = "exec ${pkgs.playerctl}/bin/playerctl play";
                  "XF86AudioPause" = "exec ${pkgs.playerctl}/bin/playerctl pause";
                  "XF86AudioNext" = "exec ${pkgs.playerctl}/bin/playerctl next";
                  "XF86AudioPrev" = "exec ${pkgs.playerctl}/bin/playerctl previous";
                };

              startup = [
                {
                  # Auto-start all *.desktop files in auto-start directories.
                  command = "${pkgs.dex}/bin/dex -a";
                }
                { command = "mako"; }
                { command = "nm-applet --indicator"; }
              ];
            };
            extraConfig = ''
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
              for_window [window_type="notification"] floating enable

              # Based on https://www.reddit.com/r/swaywm/comments/l9asbc/comment/h4pwfb4/
              for_window [app_id="Zoom"] floating enable, sticky enable
              for_window [app_id="Zoom" title="Zoom Meeting"] inhibit_idle open

              for_window [app_id="Zoom" title="as_toolbar"] floating enable, sticky enable
              for_window [app_id="Zoom" title="^(Zoom|About)$"] border pixel
              for_window [app_id="Zoom" title="Settings"] floating_minimum_size 200 x 200
            '';
          };

          services.swayosd.enable = true;
          programs.swaylock.enable = true;
          programs.swaylock.package = pkgs.swaylock-fprintd;
          programs.swaylock.settings = {
            color = backgroundColor;
            scaling = "center";
            image = "${wallpaperPng}";
          };

          services.swayidle = let
              swaylock = config.programs.swaylock.package;
            in {
            enable = true;
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
                modules-left = [ "sway/workspaces" "sway/mode" ];
                modules-center = [ ];
                modules-right = [ "network" "battery" "clock" "tray" ];
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
                  format-icons = [ "" "" "" "" "" ];
                  format-charging = "<span font='Font Awesome 5 Free'></span>  <span font='Font Awesome 5 Free 11'>{icon}</span>  {capacity}% - {time}";
                  format-full = "<span font='Font Awesome 5 Free'></span>  <span font='Font Awesome 5 Free 11'>{icon}</span>  Charged";
                };
                clock = {
                  format-alt = "{:%a, %d. %b  %H:%M}";
                };
              };
            };
          };

          programs.foot = {
            enable = true;
            server.enable = true;
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

          services.mako.enable = true;
        })
      ];
    };
}
