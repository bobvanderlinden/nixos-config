{ config
, pkgs
, lib
, ...
}: {
  imports = [
    ./modules/v4l2loopback.nix
  ];
  # Allow opening a shell during boot.
  # systemd.additionalUpstreamSystemUnits = ["debug-shell.service"];

  time.timeZone = "Europe/Amsterdam";

  suites.single-user.enable = true;
  suites.i3.enable = true;
  suites.sway.enable = false;

  boot.initrd.systemd.enable = true;

  programs.nix-ld.enable = true;

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
    driSupport = true;
    driSupport32Bit = true;
  };

  hardware.v4l2loopback.enable = true;

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
      plugins = with pkgs; [ networkmanager-openvpn ];
    };
  };

  fonts = {
    fontDir.enable = true;
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [
          "SauceCodePro Nerd Font"
        ];
      };
    };
    packages = with pkgs; [
      (nerdfonts.override { fonts = [ "SourceCodePro" ]; })
      corefonts # Microsoft free fonts
      noto-fonts
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

  # Use experimental nsncd. See https://flokli.de/posts/2022-11-18-nsncd/
  services.nscd.enableNsncd = true;

  services.acpid.enable = true;
  security.polkit.enable = true;
  services.upower.enable = true;
  services.tlp.enable = true;

  # Set permissions for RTL2832 USB dongle to use with urh.
  hardware.rtl-sdr.enable = true;

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

    # For OVR
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2833", TAG+="uaccess"

    # For OpenHMD
    SUBSYSTEM=="usb", ATTRS{idVendor}=="2833", TAG+="uaccess"
  '';

  services.locate = {
    enable = true;
    pruneNames = [ ];
  };
  services.openssh.enable = false;

  # No need for printing atm.
  # services.printing = {
  #   enable = true;
  #   drivers = with pkgs; [ gutenprint splix cups-bjnp ];
  # };

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
  services.greetd.enable = true;
  services.xserver = {
    enable = true;
    displayManager.autoLogin.enable = true;
    desktopManager.xterm.enable = false;
    updateDbusEnvironment = true;
    videoDrivers = [
      # "nouveau"
      "nvidia"
      # "modesetting"
      # "fbdev"
    ];
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
        accelSpeed = "2, 5";
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
    ibus.engines = with pkgs.ibus-engines; [ uniemoji ];
  };

  programs.fish.enable = true;
  programs.bash.enableCompletion = true;
  programs.tmux.enable = true;
  programs.adb.enable = true;

  services.redis.servers."".enable = true;

  # virtualisation.virtualbox.host.enable = true;
  virtualisation.docker = {
    enable = true;
    # daemon.settings = {
    #   ipv6 = true;
    #   "fixed-cidr-v6" = "fd00::/80";
    # };
    autoPrune.enable = true;
  };
  networking.firewall.trustedInterfaces = [ "docker0" ];

  users.defaultUserShell = pkgs.fish;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "electron-25.9.0"
  ];

  # This adds a lot of build time to the system.
  specialisation = {
    wayland.configuration = {
      suites.i3.enable = pkgs.lib.mkForce false;
      suites.sway.enable = pkgs.lib.mkForce true;
    };
    i3.configuration = {
      suites.i3.enable = pkgs.lib.mkForce true;
      suites.sway.enable = pkgs.lib.mkForce false;
    };
  };

  documentation.enable = false;
  documentation.nixos.enable = false;

  nix = {
    gc = {
      dates = "weekly";
      automatic = true;
      options = "--delete-older-than 60d";
    };
    settings = {
      sandbox = true;
      extra-sandbox-paths = [ "/etc/nix/netrc" ];
      trusted-users = [ "root" "${config.suites.single-user.user}" ];
      substituters = [ "https://cachix.cachix.org" ];
      experimental-features = [ "nix-command" "flakes" ];
      netrc-file = "/etc/nix/netrc";
      auto-optimise-store = true;
      log-lines = 100;
      warn-dirty = false;
    };
    package = pkgs.nixVersions.unstable;
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
