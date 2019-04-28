{ config, pkgs, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ./modules/towindows.nix
      ./modules/emojione.nix
      # ./modules/synaptics.nix
      ./modules/steam.nix
    ];
  nixpkgs.overlays = [
    (import ./pkgs/overlay.nix)
  ];

  time.timeZone = "Europe/Amsterdam";

  boot = {
    # Use the gummiboot efi boot loader.
    loader = {
      systemd-boot.enable = true;
      timeout = -1;
      efi.canTouchEfiVariables = true;
    };

    kernel.sysctl = {
      "fs.inotify.max_user_watches" = 100000;
    };
    extraModprobeConfig = ''
      options iwlwifi fw_monifor=1
    '';
    
    kernelModules = [ "fuse" "kvm-intel" "tun" "virtio" "coretemp" ];
    
    cleanTmpDir = true;
  };

  swapDevices = [{
    device = "/swap";
    size = 10 * 1024; # 10GB
  }];

  powerManagement.enable = true;

  # systemd.services.systemd-udev-settle.enable = false;

  hardware.enableAllFirmware = true;
  hardware.bluetooth.enable = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio = {
    enable = true;
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

    # Enable bluetooth (among others) in Pulseaudio
    package = pkgs.pulseaudioFull;
  };
  # Make sure pulseaudio is being used as sound system
  # for the different applications as well.
  nixpkgs.config.pulseaudio = true;
  
  networking = {
    hostName = "bob-laptop";

    firewall = {
      enable = true;
      allowedTCPPorts = [ 8080 ];
      allowPing = true;
    };

    defaultMailServer = {
      directDelivery = true;
      hostName = "in1-smtp.messagingengine.com";
    };

    networkmanager.enable = true;
  };

  fonts.fontconfig.ultimate.enable = true;

  environment.systemPackages = with pkgs; [
    bash
    binutils
    findutils
    unzip
    vim
    wget
    htop
    hicolor_icon_theme
    inetutils
    efibootmgr
    openvpn
    ntfs3g
    bridge-utils
    iw
    wirelesstools
    iptables
    tunctl

    gtk_engines

    docker
    
    networkmanager_openvpn
    usbutils
    avahi
  ];

  services.acpid.enable = true;
  security.polkit.enable = true;

  # Currently nixpkgs doesn't support suspend-then-hibernate yet on stable, but it
  # is in unstable. Enable this when in stable.
  # services.logind.lidSwitch = "suspend-then-hibernate";
  services.logind.lidSwitch = "suspend";

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
  # services.neo4j.enable = true;
  # services.kubernetes.roles = ["master" "node"];
  # services.kubernetes.kubelet.extraOpts = "--fail-swap-on=false";
  # services.kubernetes.kubelet.nodeIp = "192.168.1.88";

  services.gnome3 = {
    gnome-keyring.enable = true;
    seahorse.enable = true;
    gvfs.enable = false;
  };

  services.printing = {
    enable = true;
    drivers = [ pkgs.gutenprint pkgs.splix pkgs.cupsBjnp ];
  };

  services.mosquitto = {
    enable = true;
    host = "0.0.0.0";
    allowAnonymous = true;
    users = {};
  };

  services.avahi = {
    enable = true;
    browseDomains = [ ];

    # Seems to be causing trouble/slowness when resolving hosts
    #nssmdns = true;

    publish.enable = false;
  };

  services.redshift = {
    enable = true;
    provider = "geoclue2";
  };

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    displayManager.slim = {
      enable = true;
      autoLogin = true;
      defaultUser = "bob";
    };
    desktopManager.default = "none";
    desktopManager.xterm.enable = false;

    autoRepeatDelay = 145;
    autoRepeatInterval = 60;

    synaptics.enable = false;
    libinput.enable = true;
    libinput.clickMethod = "clickfinger";
    libinput.disableWhileTyping = true;
  };


  programs.zsh.enable = true;
  programs.bash.enableCompletion = true;
  programs.tmux.enable = true;
  programs.adb.enable = true;

  # virtualisation.virtualbox.host.enable = true;
  # virtualisation.docker.enable = true;

  users.defaultUserShell = "/var/run/current-system/sw/bin/zsh";
  users.extraUsers.bob = {
    uid = 1000;
    createHome = true;
    home = "/home/bob";
    extraGroups = [ "wheel" "network" "uucp" "dialout" "vboxusers" "networkmanager" "docker" "audio" "video" "input" ];
    useDefaultShell = true;
  };

  nixpkgs.config.allowUnfree = true;

  nix = {
    gc.automatic = true;
    useSandbox = true;
    package = pkgs.nixUnstable;
  };

  system.stateVersion = "18.03";
}
