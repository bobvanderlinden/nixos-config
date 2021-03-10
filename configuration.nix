{ config, pkgs, ... }:

{
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

  security.sudo.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.hsphfpd.enable = true;
  services.blueman.enable = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.opengl.extraPackages = [ pkgs.libvdpau-va-gl ];
  hardware.opengl.extraPackages32 = [ pkgs.pkgsi686Linux.libvdpau-va-gl ];
  hardware.video.hidpi.enable = true;
  hardware.pulseaudio = {
    enable = false;
    support32Bit = true;
    extraConfig = ''
      # Automatically switch to newly connected devices.
      # load-module module-switch-on-connect

      # Discover Apple iTunes devices on network.
      load-module module-raop-discover
    '';
    zeroconf.discovery.enable = true;

    # Enable extra bluetooth modules, like APT-X codec.
    extraModules = [ pkgs.pulseaudio-modules-bt ];

    # Allow bluetooth with hsphdpd support
    # package = pkgs.pulseaudio-hsphfpd.overrideAttrs (attrs: {
    #   patches = [
    #     (pkgs.fetchurl {
    #       url =
    #         "https://gitlab.freedesktop.org/pulseaudio/pulseaudio/-/merge_requests/254.diff";
    #       hash = "sha256-LTSBrA17UrbnWn4mBCnSrtK+KleGepJgOjSoLovIaTM=";
    #     })
    #   ];
    # });
    package = pkgs.pulseaudio-hsphfpd;
  };

  # Make sure pulseaudio is being used as sound system
  # for the different applications as well.
  nixpkgs.config.pulseaudio = true;
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
      google-fonts

      emacs-all-the-icons-fonts
    ];
  };

  environment.systemPackages = with pkgs; [
    bash
    findutils # find locate
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

  # This should already be handled by upower
  # services.logind.lidSwitch = "suspend";

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="0925", ATTR{idProduct}=="3881", MODE="0666"
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="21a9", ATTR{idProduct}=="1001", MODE="0666"
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="2341", ATTR{idProduct}=="0043", MODE="0666", SYMLINK+="arduino"
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", MODE="0664", GROUP="uucp"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="0043", MODE="0660", SYMLINK+="ttyArduinoUno"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", MODE="0660", SYMLINK+="ttyArduinoNano2"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", MODE="0660", SYMLINK+="ttyArduinoNano"
  '';

  services.locate.enable = true;
  services.openssh.enable = false;
  services.postgresql.enable = true;

  services.gnome3.gnome-keyring.enable = true;
  services.gvfs.enable = true;
  programs.seahorse.enable = true;

  services.printing = {
    enable = true;
    drivers = [ pkgs.gutenprint pkgs.splix pkgs.cupsBjnp ];
  };

  services.mosquitto = {
    enable = true;
    host = "0.0.0.0";
    allowAnonymous = true;
    users = { };
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
    displayManager.autoLogin.enable = true;
    displayManager.autoLogin.user = "bob.vanderlinden";
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
    libinput = {
      enable = true;
      touchpad = {
        clickMethod = "clickfinger";
        disableWhileTyping = true;
        accelProfile = "adaptive";
        accelSpeed = "0, 5";
      };
    };

    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [ dmenu i3status i3lock ];
    };
  };

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

  # virtualisation.virtualbox.host.enable = true;
  virtualisation.docker.enable = true;

  users.defaultUserShell = pkgs.zsh;

  nixpkgs.config.allowUnfree = true;

  nix = {
    gc.automatic = true;
    useSandbox = true;
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.03"; # Did you read the comment?

}

