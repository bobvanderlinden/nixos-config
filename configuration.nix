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

  suites.single-user.enable = true;
  suites.i3.enable = true;

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

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
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
  services.greetd.enable = true;
  services.xserver = {
    enable = true;
    displayManager.autoLogin.enable = true;
    desktopManager.xterm.enable = false;
    videoDrivers = ["nvidia"];
    xrandrHeads = [
      {
        output = "DP-0";
        primary = true;
      }
      "HDMI-0"
    ];

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
  };

  # Fingerprint reader
  # services.fprintd.enable = true;
  # security.pam.services.login.fprintAuth = true;
  # security.pam.services.xscreensaver.fprintAuth = true;

  i18n.inputMethod = {
    enabled = "ibus";
    ibus.engines = with pkgs.ibus-engines; [uniemoji];
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
      suites.i3.enable = pkgs.lib.mkForce false;
      suites.sway.enable = true;
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
      trusted-users = ["root" "${config.suites.single-user.user}"];
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
