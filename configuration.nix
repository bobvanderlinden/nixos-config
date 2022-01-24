{ config, pkgs, ... }:

{
  imports = [
    ./modules/v4l2loopback.nix
  ];
  systemd.additionalUpstreamSystemUnits = [ "debug-shell.service" ];

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

  hardware.bluetooth.enable = true;
  hardware.bluetooth.hsphfpd.enable = true;

  # Workaround: https://github.com/NixOS/nixpkgs/issues/114222
  systemd.user.services.telephony_client.enable = false;

  services.blueman.enable = true;
  hardware.opengl = {
    enable = true;
    driSupport32Bit = true;
  };

  hardware.v4l2loopback.enable = true;
  
  hardware.video.hidpi.enable = true;
  hardware.pulseaudio = {
    enable = true;
    support32Bit = true;
    extraConfig = ''
      # Automatically switch to newly connected devices.
      # load-module module-switch-on-connect
    '';

    # Enable extra bluetooth modules, like APT-X codec.
    extraModules = [ pkgs.pulseaudio-modules-bt ];

    # package = pkgs.pulseaudio-hsphfpd;
    package = pkgs.pulseaudioFull;
  };

  # Make sure pulseaudio is being used as sound system
  # for the different applications as well.
  nixpkgs.config.pulseaudio = true;

  services.ssmtp = {
    # directDelivery = true;
    hostName = "in1-smtp.messagingengine.com";
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

    networkmanager.enable = true;
    networkmanager.packages = [ pkgs.networkmanager_openvpn ];
  };

  fonts = {
    fontDir.enable = true;
    fontconfig.enable = true;
    fonts = with pkgs; [
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
    drivers = [ pkgs.gutenprint pkgs.splix pkgs.cupsBjnp ];
  };

  services.avahi = {
    enable = true;
    browseDomains = [ ];

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
    videoDrivers = [ "nvidia" ];
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
      extraPackages = with pkgs; [ dmenu i3status i3lock ];
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
    ibus.engines = with pkgs.ibus-engines; [ uniemoji ];
  };

  services.actkbd = {
    enable = true;
    bindings = [
      # "Mute" media key
      {
        keys = [ 121 ];
        events = [ "key" ];
        command = "${pkgs.alsaUtils}/bin/amixer -q set Master toggle";
      }

      # "Mute Microphone" button
      {
        keys = [ 190 ];
        events = [ "key" ];
        command = "${pkgs.alsaUtils}/bin/amixer -q set Capture toggle";
      }

      # "Lower Volume" media key
      {
        keys = [ 122 ];
        events = [ "key" "rep" ];
        command = "${pkgs.alsaUtils}/bin/amixer -q set Master 5%- unmute";
      }

      # "Raise Volume" media key
      {
        keys = [ 123 ];
        events = [ "key" "rep" ];
        command = "${pkgs.alsaUtils}/bin/amixer -q set Master 5%+ unmute";
      }

      # "Phone connect"
      {
        keys = [ 56 125 218 ];
        events = [ "key" ];
        command =
          "${pkgs.pulseaudio}/bin/pactl set-card-profile bluez_card.2C:41:A1:C8:E5:04 headset-head-unit";
      }

      # "Phone disconnect"
      {
        keys = [ 29 56 223 ];
        events = [ "key" ];
        command =
          "${pkgs.pulseaudio}/bin/pactl set-card-profile bluez_card.2C:41:A1:C8:E5:04 a2dp-sink-aac";
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
    pipewire.configuration = {
      hardware.pulseaudio.enable = pkgs.lib.mkForce false;
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
    };
  };

  nix = {
    gc = {
      dates = "weekly";
      automatic = true;
      options = "--delete-older-than 60d";
    };
    useSandbox = true;
    package = pkgs.nixFlakes;
    sandboxPaths = [ "/etc/nix/netrc" ];
    trustedUsers = [ "root" "bob.vanderlinden" ];
    binaryCaches = [ "https://cachix.cachix.org" ];
    extraOptions = ''
      experimental-features = nix-command flakes ca-references
      netrc-file = /etc/nix/netrc
    '';
  };

  system.autoUpgrade = {
    enable = false;
    flake = "/home/bob.vanderlinden/projects/bobvanderlinden/nixos-config";
    flags = [ "--update-input" "nixpkgs" "--commit-lock-file" ];
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

