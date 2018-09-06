{ config, pkgs, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ./modules/towindows.nix
      ./modules/emojione.nix
      ./modules/synaptics.nix
    ];
  nixpkgs.overlays = [
    (import ./pkgs/overlay.nix)
  ];

  time.timeZone = "Europe/Amsterdam";

  hardware.enableAllFirmware = true;

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


  hardware.bluetooth.enable = true;
  hardware.pulseaudio = {
    enable = true;
    support32Bit = true;

    # Enable bluetooth (among others) in Pulseaudio
    package = pkgs.pulseaudioFull;
  };
  # Make sure pulseaudio is being used as sound system
  # for the different applications as well.
  nixpkgs.config.pulseaudio = true;
  
  networking = {
    hostName = "bob-laptop";
    enableIPv6 = false;

    firewall = {
      enable = false;
      allowedTCPPorts = [ 8080 ];
      allowPing = true;
    };

    defaultMailServer = {
      directDelivery = true;
      hostName = "in1-smtp.messagingengine.com";
    };

    networkmanager.enable = true;
  };

  environment.systemPackages = with pkgs; [
    bash
    binutils
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
  services.logind.extraConfig = ''
    HandlePowerKey=hibernate
    HandleSuspendKey=suspend
    HandleHibernateKey=hibernate
    HandleLidSwitch=suspend
  '';

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
  services.openssh.enable = true;
  services.postgresql.enable = true;

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
  };


  programs.zsh.enable = true;
  programs.bash.enableCompletion = true;
  programs.tmux.enable = true;

  virtualisation.virtualbox.host.enable = true;
  virtualisation.docker.enable = true;

  users.defaultUserShell = "/var/run/current-system/sw/bin/zsh";
  users.extraUsers.bob = {
    uid = 1000;
    createHome = true;
    home = "/home/bob";
    extraGroups = [ "wheel" "network" "uucp" "dialout" "vboxusers" "networkmanager" "docker" "audio" ];
    useDefaultShell = true;
  };

  nixpkgs.config.allowUnfree = true;

  nix = {
    gc.automatic = true;
    useSandbox = true;
    package = pkgs.nixUnstable;
  };
}
