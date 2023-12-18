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
    in
    mkIf cfg.enable {
      suites.wayland.enable = mkDefault true;

      services.xserver.displayManager.defaultSession = mkDefault "sway";

      # Prevent restarting sway when using nixos-rebuild switch
      systemd.services.sway.restartIfChanged = false;

      services.greetd.enable = mkForce false;
      services.xserver.displayManager.gdm.enable = mkForce true;


      programs.sway = {
        enable = true;
        wrapperFeatures.gtk = true;
        extraOptions = [ "--unsupported-gpu" ];
        extraPackages = with pkgs; [
          wl-clipboard
          mako
          foot
          wofi
        ];
        extraSessionCommands = ''
          # export WLR_NO_HARDWARE_CURSORS=1
        '';
      };
      xdg.portal = {
        enable = true;
        wlr = {
          enable = true;
          settings = {
            screencast = {
              chooser_type = "none";
              region = "0,0:3840x2160";
              cropmode = "pipewire";
            };
          };
        };
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        configPackages = config.xdg.portal.extraPortals ++ (with pkgs; [
          gnome.gnome-keyring
        ]);
      };

      home-manager.sharedModules = [
        {
          home.packages = with pkgs; [
            swaylock
            wlr-randr
          ];

          wayland.windowManager.sway = rec {
            enable = true;
            wrapperFeatures.gtk = true;
            systemd.enable = true;
            xwayland = true;
            extraOptions = [ "--unsupported-gpu" ];
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

                  "XF86AudioRaiseVolume" = "exec ${pkgs.pamixer}/bin/pamixer --increase 5";
                  "XF86AudioLowerVolume" = "exec ${pkgs.pamixer}/bin/pamixer --decrease 5";
                  "XF86AudioMute" = "exec ${pkgs.pamixer}/bin/pamixer --toggle-mute";

                  "XF86MonBrightnessUp" = "exec ${pkgs.brightnessctl}/bin/brightnessctl set +2%";
                  "XF86MonBrightnessDown" = "exec ${pkgs.brightnessctl}/bin/brightnessctl set 2%-";

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

              workspace "10" output DVI-I-0

              for_window [class="Bitwarden"] move scratchpad
              for_window [class="Bitwarden"] sticky enable
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

              # From https://www.reddit.com/r/swaywm/comments/l9asbc/comment/h4pwfb4/
              for_window [app_id="zoom"] floating enable, sticky enable
              for_window [app_id="zoom" title="Zoom Meeting"] inhibit_idle open

              for_window [app_id="zoom" title="^(Zoom|About)$"] border pixel, floating enable
              for_window [app_id="zoom" title="Settings"] floating enable, floating_minimum_size 960 x 700
              # Open Zoom Meeting windows on a new workspace (a bit hacky)
              for_window [app_id="zoom" title="Zoom Meeting(.*)?"] floating disable, inhibit_idle open
            '';
          };

          services.swayidle = {
            enable = true;
            timeouts = [
              {
                timeout = 5 * 60;
                command = "swaylock -f";
              }
            ];
            events = [
              {
                event = "before-sleep";
                command = "swaylock -f";
              }
              {
                event = "lock";
                command = "swaylock -f";
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
        }
      ];
    };
}
