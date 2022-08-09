{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options = {
    suites.i3 = {
      enable = mkEnableOption "i3 suite";
    };
  };

  config = let
    cfg = config.suites.i3;
    pulseaudio = pkgs.pulseaudio;
  in
    mkIf cfg.enable {
      services.xserver.displayManager.defaultSession = "none+i3";
      services.xserver.windowManager.i3 = {
        enable = true;
        extraPackages = with pkgs; [dmenu i3status i3lock];
      };
      services.picom = {
        enable = true;
        vSync = true;
      };
      xdg.portal = {
        enable = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-gtk
        ];
      };

      programs.xss-lock.enable = true;
      services.gnome.gnome-keyring.enable = true;
      services.gvfs.enable = true;
      programs.seahorse.enable = true;

      services.actkbd = {
        enable = true;
        bindings = [
          # "Mute" media key
          {
            keys = [121];
            events = ["key"];
            command = "${pkgs.alsaUtils}/bin/amixer -q set Master toggle";
          }

          # "Mute Microphone" button
          {
            keys = [190];
            events = ["key"];
            command = "${pkgs.alsaUtils}/bin/amixer -q set Capture toggle";
          }

          # "Lower Volume" media key
          {
            keys = [122];
            events = ["key" "rep"];
            command = "${pkgs.alsaUtils}/bin/amixer -q set Master 5%- unmute";
          }

          # "Raise Volume" media key
          {
            keys = [123];
            events = ["key" "rep"];
            command = "${pkgs.alsaUtils}/bin/amixer -q set Master 5%+ unmute";
          }

          # "Phone connect"
          {
            keys = [56 125 218];
            events = ["key"];
            command = "${pulseaudio}/bin/pactl set-card-profile bluez_card.2C:41:A1:C8:E5:04 headset-head-unit";
          }

          # "Phone disconnect"
          {
            keys = [29 56 223];
            events = ["key"];
            command = "${pulseaudio}/bin/pactl set-card-profile bluez_card.2C:41:A1:C8:E5:04 a2dp-sink-aac";
          }
        ];
      };

      home-manager.sharedModules = [
        {
          xresources.properties = {"Xft.dpi" = 192;};

          programs.i3status = {
            enable = true;
            enableDefault = false;
            general = {
              colors = true;
              interval = 5;
            };
            modules = {
              "wireless wlp0s20f3" = {
                position = 1;
                settings = {
                  format_up = "W: (%quality at %essid) %ip";
                  format_down = "W: down";
                };
              };

              "battery 0" = {
                position = 2;
                settings = {
                  format = "%status %percentage %remaining";
                };
              };

              "tztime local" = {
                position = 3;
                settings = {
                  format = "%Y-%m-%d %H:%M:%S";
                };
              };
            };
          };

          # Desktop notifications
          services.dunst = {
            enable = true;
            settings = rec {
              global = {
                markup = "none";
                format = ''
                  <big><b>%s</b></big>
                  %b
                '';
                sort = false;
                alignment = "left";
                bounce_freq = 0;
                word_wrap = true;
                ignore_newline = false;
                geometry = "450x100-15+49";
                transparency = 10;
                separator_height = 2;
                padding = 12;
                horizontal_padding = 20;
                line_height = 3;
                separator_color = "frame";
                frame_width = 2;
                frame_color = "#EC5F67";
              };

              urgency_normal = {
                foreground = "#CDD3DE";
                background = "#101010";
                timeout = 6;
              };
              urgency_low = urgency_normal;
              urgency_critical = urgency_normal;
            };
          };

          xsession = {
            enable = true;
            windowManager.i3 = rec {
              enable = true;
              config = {
                modifier = "Mod4";
                # bars = [{ statusCommand = "${pkgs.i3status}/bin/i3status"; }];
                keybindings = let
                  mod = config.modifier;
                in {
                  "${mod}+t" = "exec terminator";
                  "${mod}+w" = "exec chromium --disable-gpu-driver-bug-workarounds --ignore-gpu-blocklist --enable-gpu-rasterization --enable-zero-copy --enable-features=VaapiVideoDecoder";
                  "${mod}+e" = "exec thunar";
                  "${mod}+q" = "exec dmenu_run";
                  "${mod}+Delete" = "exec i3lock";
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
                  "${mod}+h" = "split h";
                  "${mod}+v" = "split v";
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
                    exec "i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3? This will end your X session.' -b 'Yes, exit i3' 'i3-msg exit'"'';

                  "XF86AudioRaiseVolume" = "exec ${pulseaudio}/bin/pactl set-sink-volume 0 +5%";
                  "XF86AudioLowerVolume" = "exec ${pulseaudio}/bin/pactl set-sink-volume 0 -5%";
                  "XF86AudioMute" = "exec ${pulseaudio}/bin/pactl set-sink-mute 0 toggle";

                  "XF86MonBrightnessUp" = "exec ${pkgs.xorg.xbacklight}/bin/xbacklight -inc 5";
                  "XF86MonBrightnessDown" = "exec ${pkgs.xorg.xbacklight}/bin/xbacklight -dec 5";

                  "XF86AudioPlay" = "exec ${pkgs.playerctl}/bin/playerctl play";
                  "XF86AudioPause" = "exec ${pkgs.playerctl}/bin/playerctl pause";
                  "XF86AudioNext" = "exec ${pkgs.playerctl}/bin/playerctl next";
                  "XF86AudioPrev" = "exec ${pkgs.playerctl}/bin/playerctl previous";
                };

                startup = [
                  {
                    # Auto-start all *.desktop files in auto-start directories.
                    command = "${pkgs.dex}/bin/dex -a";
                    notification = false;
                  }
                ];
              };
              extraConfig = ''
                default_orientation horizontal
                workspace_layout tabbed

                workspace "10" output DVI-I-0
                assign [class="Pidgin"] "10"
                assign [class="Spotify"] = "10"

                for_window [class="Bitwarden"] move scratchpad
                for_window [class="Bitwarden"] sticky enable
                for_window [class="gnome-pomodoro"] move scratchpad
                for_window [class="gnome-pomodoro"] sticky enable
                for_window [class="floating"] floating enable
                for_window [title="Zoom Meeting"] floating enable
                for_window [title="Zoom Meeting"] sticky enable

                for_window [window_type="dialog"] floating enable
                for_window [window_type="utility"] floating enable
                for_window [window_type="toolbar"] floating enable
                for_window [window_type="splash"] floating enable
                for_window [window_type="menu"] floating enable
                for_window [window_type="dropdown_menu"] floating enable
                for_window [window_type="popup_menu"] floating enable
                for_window [window_type="tooltip"] floating enable
                for_window [window_type="notification"] floating enable
              '';
            };
          };
        }
      ];
    };
}
