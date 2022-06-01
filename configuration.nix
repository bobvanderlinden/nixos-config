{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./modules/v4l2loopback.nix
  ];
  systemd.additionalUpstreamSystemUnits = ["debug-shell.service"];

  time.timeZone = "Europe/Amsterdam";

  users.users."bob.vanderlinden" = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "network"
      "uucp"
      "dialout"
      "vboxusers"
      "networkmanager"
      "docker"
      "audio"
      "video"
      "input"
      "sudo"
    ];
    useDefaultShell = true;
  };

  boot.initrd.systemd.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Smartcard daemon for Yubikey
  services.pcscd.enable = true;

  security.sudo.enable = true;

  hardware.bluetooth = {
    enable = true;
    # hsphfpd.enable = true;
    settings = {
      General = {
        # To enable BlueZ Battery Provider
        Experimental = true;
      };
    };
  };

  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };

  # Workaround: https://github.com/NixOS/nixpkgs/issues/114222
  systemd.user.services.telephony_client.enable = false;

  hardware.opengl = {
    enable = true;
    driSupport32Bit = true;
  };

  hardware.v4l2loopback.enable = true;

  hardware.video.hidpi.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;

    media-session.config.bluez-monitor.properties = {
      # MSBC is not expected to work on all headset + adapter combinations.
      "bluez5.msbc-support" = true;
      "bluez5.sbc-xq-support" = true;
    };
  };

  networking = {
    hostName = "NVC3919";

    firewall = {
      enable = true;
      allowedTCPPorts = [
        3000 # Development
        8080 # Development
      ];
      allowPing = true;
    };

    networkmanager = {
      enable = true;
      plugins = with pkgs; [networkmanager-openvpn];
    };
  };

  fonts = {
    fontDir.enable = true;
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [
          "DejaVu Sans Mono for Powerline Book"
        ];
      };
    };
    fonts = with pkgs; [
      font-awesome
      corefonts # Microsoft free fonts
      iosevka
      meslo-lg
      # nerdfonts
      source-code-pro
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji

      # emacs-all-the-icons-fonts
    ];
  };

  environment.systemPackages = with pkgs; [
    bash
    moreutils # sponge...
    unzip
    vim
    wget
    htop
    efibootmgr

    # Networking tools
    inetutils # hostname ping ifconfig...
    dnsutils # dig nslookup...
    bridge-utils # brctl
    iw
    wirelesstools # iwconfig

    docker

    usbutils # lsusb
  ];

  services.acpid.enable = true;
  security.polkit.enable = true;
  services.upower.enable = true;

  services.udev.extraRules = ''
    # Thunderbolt
    # Always authorize thunderbolt connections when they are plugged in.
    # This is to make sure the USB hub of Thunderbolt is working.
    ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"

    # Saleae Logic Analyzer
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="0925", ATTR{idProduct}=="3881", MODE="0666"
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="21a9", ATTR{idProduct}=="1001", MODE="0666"

    # Arduino
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="2341", ATTR{idProduct}=="0043", MODE="0666", SYMLINK+="arduino"
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", MODE="0664", GROUP="uucp"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="0043", MODE="0660", SYMLINK+="ttyArduinoUno"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", MODE="0660", SYMLINK+="ttyArduinoNano2"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", MODE="0660", SYMLINK+="ttyArduinoNano"
  '';

  services.locate = {
    enable = true;
    pruneNames = [];
  };
  services.openssh.enable = false;

  services.gnome.gnome-keyring.enable = true;
  services.gvfs.enable = true;
  programs.seahorse.enable = true;

  services.printing = {
    enable = true;
    drivers = with pkgs; [gutenprint splix cups-bjnp];
  };

  services.avahi = {
    enable = true;
    browseDomains = [];

    # Seems to be causing trouble/slowness when resolving hosts
    #nssmdns = true;

    publish.enable = false;
  };

  services.redshift.enable = true;
  location.provider = "geoclue2";

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    displayManager.defaultSession = "none+i3";
    displayManager.lightdm.enable = true;
    desktopManager.xterm.enable = false;
    videoDrivers = ["nvidia"];
    xrandrHeads = [
      {
        output = "DP-0";
        primary = true;
      }
      "HDMI-0"
    ];

    autoRepeatDelay = 300;
    autoRepeatInterval = 60;

    synaptics.enable = false;
    # wacom.enable = true;
    libinput = {
      enable = true;
      touchpad = {
        clickMethod = "clickfinger";
        disableWhileTyping = true;
        accelProfile = "adaptive";
        accelSpeed = "0, 5";
      };
      mouse = {
        accelSpeed = "1";
      };
    };

    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [dmenu i3status i3lock];
    };
  };
  services.picom = {
    enable = true;
    vSync = true;
  };
  programs.xss-lock.enable = true;

  # Fingerprint reader
  # services.fprintd.enable = true;
  # security.pam.services.login.fprintAuth = true;
  # security.pam.services.xscreensaver.fprintAuth = true;

  i18n.inputMethod = {
    enabled = "ibus";
    ibus.engines = with pkgs.ibus-engines; [uniemoji];
  };

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
        command = "${pkgs.pulseaudio}/bin/pactl set-card-profile bluez_card.2C:41:A1:C8:E5:04 headset-head-unit";
      }

      # "Phone disconnect"
      {
        keys = [29 56 223];
        events = ["key"];
        command = "${pkgs.pulseaudio}/bin/pactl set-card-profile bluez_card.2C:41:A1:C8:E5:04 a2dp-sink-aac";
      }
    ];
  };
  # users.extraUsers.bob.extraGroups = [ "sway" ];
  # programs.sway.enable = true;

  programs.zsh.enable = true;
  programs.zsh.enableCompletion = true;
  programs.bash.enableCompletion = true;
  programs.tmux.enable = true;
  programs.adb.enable = true;

  services.mysql = {
    enable = true;
    package = pkgs.mysql;
  };
  services.redis.servers."".enable = true;

  # virtualisation.virtualbox.host.enable = true;
  virtualisation.docker = {
    enable = true;
    # daemon.settings = {
    #   ipv6 = true;
    #   "fixed-cidr-v6" = "fd00::/80";
    # };
  };

  users.defaultUserShell = pkgs.zsh;

  nixpkgs.config.allowUnfree = true;

  specialisation = {
    wayland.configuration = {
      # Unfortunately this must be true for GDM to work properly.
      services.xserver.enable = true;

      services.picom.enable = pkgs.lib.mkForce false;

      services.xserver.displayManager.lightdm.enable = pkgs.lib.mkForce false;
      systemd.services.display-manager.enable = true;
      services.xserver.displayManager.gdm.enable = true;
      services.xserver.displayManager.gdm.wayland = true;
      services.xserver.displayManager.defaultSession = pkgs.lib.mkForce "sway";
      services.xserver.videoDrivers = pkgs.lib.mkForce [];

      # Prevent restarting sway when using nixos-rebuild switch
      systemd.services.sway.restartIfChanged = false;

      programs.sway = {
        enable = true;
        extraPackages = with pkgs; [
          wl-clipboard
          mako
          foot
          wofi
        ];
        extraSessionCommands = ''
          # Source: https://github.com/cole-mickens/nixcfg/blob/707b2db0a5f69ffda027f8008835f01d03954dcb/mixins/nvidia.nix#L7-L13
          export GBM_BACKEND=nvidia-drm
          export __GLX_VENDOR_LIBRARY_NAME=nvidia
          export WLR_NO_HARDWARE_CURSORS=1

          # Source: https://gist.github.com/zimbatm/b82817b7feb5b58a8003d6afced62065#file-sway-nix-L56-L69
          # SDL:
          export SDL_VIDEODRIVER=wayland
          # QT (needs qt5.qtwayland in systemPackages):
          export QT_QPA_PLATFORM=wayland-egl
          export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
          # Fix for some Java AWT applications (e.g. Android Studio),
          # use this if they aren't displayed properly:
          export _JAVA_AWT_WM_NONREPARENTING=1
        '';
      };
      xdg.portal = {
        enable = true;
        wlr.enable = true;
        gtkUsePortal = true;
        # extraPortals = with pkgs; [
        #   xdg-desktop-portal-gtk
        #   # xdg-desktop-portal-kde
        # ];
      };

      home-manager.users."bob.vanderlinden" = {
        services.dunst.enable = pkgs.lib.mkForce false;
        services.network-manager-applet.enable = pkgs.lib.mkForce false;
        xsession.enable = pkgs.lib.mkForce false;
        xsession.windowManager.i3.enable = pkgs.lib.mkForce false;

        wayland.windowManager.sway = rec {
          enable = true;
          systemdIntegration = true;
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
            keybindings = let
              mod = config.modifier;
            in {
              "${mod}+t" = "exec foot";
              "${mod}+w" = "exec chromium";
              "${mod}+e" = "exec thunar";
              "${mod}+q" = "exec ${pkgs.dmenu}/bin/dmenu_run";
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

              "XF86AudioRaiseVolume" = "exec ${pkgs.pamixer}/bin/pamixer --increase 5";
              "XF86AudioLowerVolume" = "exec ${pkgs.pamixer}/bin/pamixer --decrease 5";
              "XF86AudioMute" = "exec ${pkgs.pamixer} --toggle-mute";

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
              {command = "mako";}
              {command = "nm-applet --indicator";}
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
            for_window [class="zoom"] floating enable
            for_window [class="zoom"] sticky enable

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
          style = let
            # base16-default-dark-css = pkgs.fetchurl {
            #   url = "https://raw.githubusercontent.com/mnussbaum/base16-waybar/d2f943b1abb9c9f295e4c6760b7bdfc2125171d2/colors/base16-default-dark.css";
            #   hash = "sha256:1dncxqgf7zsk39bbvrlnh89lsgr2fnvq5l50xvmpnibk764bz0jb";
            # };
            style = pkgs.fetchurl {
              url = "https://raw.githubusercontent.com/robertjk/dotfiles/253b86442dae4d07d872e8b963fa33b5f8819594/.config/waybar/style.css";
              hash = "sha256-7bEOPMslgpXsKOa2aMqVoV5z1OSSRqXs2UGDgWwejx4=";
            };
          in ''
            @import "${style}";
          '';
          settings = {
            mainBar = {
              position = "bottom";
              modules-left = ["sway/workspaces" "sway/mode"];
              modules-center = [];
              modules-right = ["network" "battery" "clock" "tray"];
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
                format-icons = ["" "" "" "" ""];
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

        programs.mako.enable = true;
      };
    };
  };

  nix = {
    gc = {
      dates = "weekly";
      automatic = true;
      options = "--delete-older-than 60d";
    };
    settings = {
      sandbox = true;
      extra-sandbox-paths = ["/etc/nix/netrc"];
      trusted-users = ["root" "bob.vanderlinden"];
      substituters = ["https://cachix.cachix.org"];
      experimental-features = ["nix-command" "flakes"];
      netrc-file = "/etc/nix/netrc";
    };
    package = pkgs.nixFlakes;
  };

  system.autoUpgrade = {
    enable = false;
    flake = "/home/bob.vanderlinden/projects/bobvanderlinden/nixos-config";
    flags = ["--update-input" "nixpkgs" "--commit-lock-file"];
    dates = "17:30";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.03"; # Did you read the comment?
}
