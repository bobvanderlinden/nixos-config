{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  # Allow opening a shell during boot.
  # systemd.additionalUpstreamSystemUnits = ["debug-shell.service"];

  time.timeZone = "Europe/Amsterdam";

  suites.single-user.enable = true;

  boot.initrd.systemd.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.plymouth.enable = true;
  boot.consoleLogLevel = 3;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "quiet"
    "udev.log_priority=3"
    "plymouth.use-simpledrm"
    "plymouth.boot-log=/dev/null"
  ];
  boot.loader.timeout = 0;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Prefer keeping inactive pages in RAM/zram over writing them to disk swap.
  boot.kernel.sysctl."vm.swappiness" = 10;
  swapDevices = lib.mkForce [
    { device = "/swapfile"; }
  ];
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  programs.nix-ld.enable = true;
  programs.ydotool = {
    enable = true;
    group = "input";
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

  security.wrappers.pkexec = {
    source = "${pkgs.polkit}/bin/pkexec";
    owner = "root";
    group = "root";
    setuid = true;
  };

  # On my desktop I don't want to run into file limitations.
  # Using vite with a large project made Chromium reach the
  # limit, resulting in weird behaviour without proper errors. Never again.
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "-1";
    }
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "-1";
    }
  ];

  hardware.bluetooth = {
    enable = true;
    settings = {
      General = {
        # To enable BlueZ Battery Provider
        Experimental = true;
      };
    };
  };
  services.blueman.enable = true;

  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };

  hardware.graphics.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
  };

  networking = {
    hostName = "nac44250";

    firewall.enable = true;

    networkmanager = {
      enable = true;
      plugins = with pkgs; [ networkmanager-openvpn ];
    };
  };
  services.resolved.enable = true;
  programs.openvpn3.enable = true;
  programs.networkmanager-openvpn3.enable = true;

  fonts = {
    fontDir.enable = true;
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "SauceCodePro Nerd Font" ];
      };
    };
    packages =
      with pkgs;
      [
        corefonts # Microsoft free fonts
        noto-fonts
        noto-fonts-color-emoji
      ]
      ++ (with nerd-fonts; [
        sauce-code-pro
      ]);
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

    polkit_gnome

    sbctl

    android-tools
  ];

  # Use experimental nsncd. See https://flokli.de/posts/2022-11-18-nsncd/
  services.nscd.enableNsncd = true;

  services.acpid.enable = true;
  services.fwupd = {
    enable = true;
    uefiCapsuleSettings = {
      EnableEfiDebugging = true;
    };
  };
  security.polkit.enable = true;
  # Suspend after the default idle timeout (30 minutes). opencode holds a sleep
  # inhibitor while an agent is running, so this won't fire mid-task.
  services.logind.settings.Login.IdleAction = "suspend";
  services.upower = {
    enable = true;
    timeAction = 15 * 60;
    percentageCritical = 10;
  };
  services.tlp = {
    enable = true;
    settings = {
      # Reduce power consumption and fan noise on AC power
      # Source: https://linrunner.de/tlp/support/optimizing.html#reduce-power-consumption-fan-noise-on-ac-power

      # CPU frequency scaling
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # CPU energy performance preference
      CPU_ENERGY_PERF_POLICY_ON_AC = "power";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # CPU boost
      CPU_BOOST_ON_AC = 0;
      CPU_BOOST_ON_BAT = 0;

      # CPU HWP dynamic boost
      CPU_HWP_DYN_BOOST_ON_AC = 0;
      CPU_HWP_DYN_BOOST_ON_BAT = 0;

      # Platform profile
      PLATFORM_PROFILE_ON_AC = "low-power";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # PCIe Active State Power Management
      PCIE_ASPM_ON_AC = "powersupersave";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # Runtime power management
      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";

      # WiFi power saving
      WIFI_PWR_ON_AC = "on";
      WIFI_PWR_ON_BAT = "on";
    };
  };
  services.earlyoom.enable = true;

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

    # Allow wheel users to access all USB drives.
    SUBSYSTEMS=="usb|mmc", ENV{DEVTYPE}=="disk", MODE="0660", GROUP="wheel"
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

  location = {
    # https://github.com/jonls/redshift/issues/318.
    # provider = "geoclue2";
    provider = "manual";
    latitude = 51.974882858758626;
    longitude = 5.9115896491034565;
  };

  programs.hyprland = {
    enable = true;
  };
  programs.regreet.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.dbus}/bin/dbus-run-session ${lib.getExe pkgs.cage} -s -d -- ${lib.getExe config.programs.regreet.package}";
        user = "greeter";
      };
      initial_session = {
        command = "${lib.getExe' config.programs.hyprland.package "start-hyprland"}";
        user = config.suites.single-user.user;
      };
    };
  };
  services.systemd-lock-handler.enable = true;

  # Fingerprint reader
  security.pam.services.hyprlock = { };

  programs.fish.enable = true;
  programs.bash.completion.enable = true;
  programs.tmux.enable = true;

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ config.suites.single-user.user ];
  };

  services.flatpak.enable = true;

  # Thunar file manager support
  services.gvfs.enable = true; # For trash, mounting remote filesystems, etc.
  services.tumbler.enable = true; # For thumbnail generation

  # virtualisation.virtualbox.host.enable = true;
  virtualisation.docker = {
    enable = true;
    # daemon.settings = {
    #   ipv6 = true;
    #   "fixed-cidr-v6" = "fd00::/80";
    # };
    autoPrune.enable = true;
  };

  virtualisation.podman = {
    enable = true;
  };
  networking.firewall.trustedInterfaces = [ "docker0" ];

  users.defaultUserShell = pkgs.fish;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "electron-25.9.0"
    # Bitwarden desktop depends on Electron 39 until upstream/nixpkgs moves it to a supported Electron.
    # See https://github.com/NixOS/nixpkgs/issues/526914
    "electron-39.8.10"
  ];

  # hardware-configuration.nix enables the broad firmware bundles, but on this
  # HP laptop we only observed firmware usage for the Intel AX211 Wi-Fi and
  # Bluetooth, Intel iGPU, Intel SOF audio, and Cirrus speaker amp firmware.
  # Keep the firmware list explicit so nixpkgs updates do not pull in unrelated
  # bundles like the duplicate b43 variants that caused build warnings.
  hardware.enableAllFirmware = lib.mkForce false;
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.firmware = with pkgs; [
    linux-firmware
    sof-firmware
    wireless-regdb
  ];

  documentation.man.cache.enable = false;
  documentation.nixos.enable = false;

  # system.replaceRuntimeDependencies = [
  #   ({
  #     original = pkgs.xz;
  #     replacement = pkgs.xz.overrideAttrs (oldAttrs: {
  #       src = pkgs.fetchurl {
  #         url = "mirror://sourceforge/lzmautils/xz-5.4.6.tar.bz2";
  #         sha256 = "sha256-kThRsnTo4dMXgeyUnxwj6NvPDs9uc6JDbcIXad0+b0k=";
  #       };
  #     });
  #   })
  # ];

  nix = {
    registry.nixpkgs.flake = inputs.nixpkgs;

    gc = {
      dates = "weekly";
      automatic = true;
      options = "--delete-older-than 60d";
    };

    settings = {
      # Source: https://github.com/NixOS/nix/issues/11728
      download-buffer-size = 524288000;

      sandbox = true;
      extra-sandbox-paths = [ "/etc/nix/netrc" ];
      trusted-users = [
        "root"
        "${config.suites.single-user.user}"
      ];
      substituters = [ "https://cachix.cachix.org" ];
      extra-substituters = [ "https://install.determinate.systems" ];
      extra-trusted-public-keys = [ "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM=" ];
      extra-experimental-features = [
        "nix-command"
        "flakes"
        # Bug in Determinate-Nix: https://github.com/cachix/devenv/issues/2364
        # "ca-derivations"
      ];
      netrc-file = "/etc/nix/netrc";
      auto-optimise-store = true;
      log-lines = 100;
      warn-dirty = false;
      # Only for Determinate-Nix
      lazy-trees = true;
      eval-cache = true;
      eval-cores = 0;
    };
  };

  system.autoUpgrade = {
    enable = false;
    flake = "/home/bob.vanderlinden/projects/bobvanderlinden/nixos-config";
    flags = [
      "--update-input"
      "nixpkgs"
      "--commit-lock-file"
    ];
    dates = "17:30";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.03"; # Did you read the comment?

  programs.localsend = {
    enable = true;
  };
}
