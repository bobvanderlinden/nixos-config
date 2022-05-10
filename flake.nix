{
  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      # "https://cachix.cachix.org"
      "https://alejandra.cachix.org"
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    alejandra.url = "github:kamadorueda/alejandra";
    jujutsu.url = "github:martinvonz/jj";
  };

  outputs = inputs: let
    system = "x86_64-linux";
    username = "bob.vanderlinden";

    overlay = final: prev: {
      coin = final.callPackage ./packages/coin {};
      gnome-dbus-emulation-wlr = final.callPackage ./packages/gnome-dbus-emulation-wlr {};
      jujutsu = inputs.jujutsu.defaultPackage.${system};
      alejandra = inputs.alejandra.defaultPackage.${system};
    };

    pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        overlay
      ];
    };
  in rec {
    inherit overlay;

    packages.${system} = {
      inherit (pkgs) coin jujutsu gnome-dbus-emulation-wlr;
    };

    homeManagerConfigurations.${username} = inputs.home-manager.lib.homeManagerConfiguration {
      inherit system username pkgs;
      configuration = ./home/default.nix;
      homeDirectory = "/home/${username}";
    };

    nixosModules.hp-zbook-studio-g5 = {
      pkgs,
      config,
      ...
    }: {
      imports = with inputs.nixos-hardware.nixosModules; [
        # common-cpu-intel
        # common-gpu-nvidia
        common-pc-laptop-ssd
        common-pc-laptop
      ];

      # Replacement for common-cpu-intel
      boot.initrd.kernelModules = ["i915"];
      hardware.cpu.intel.updateMicrocode = config.hardware.enableRedistributableFirmware;

      # Replacement for common-gpu-nvidia
      services.xserver.videoDrivers = ["nvidia"];

      # nixos-hardware defaults to va_gl for intel chipsets.
      # This breaks on systems with nvidia.
      # See https://github.com/NixOS/nixos-hardware/issues/388
      environment.variables.VDPAU_DRIVER = "nvidia";

      hardware.nvidia.powerManagement.enable = true;
      hardware.enableRedistributableFirmware = true;

      # hardware.opengl.extraPackages = with pkgs; [
      #   vaapiVdpau
      #   libvdpau-va-gl
      # ];
      # hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [
      #   vaapiVdpau
      #   libvdpau-va-gl
      # ];
    };
    nixosModules.overlays = {nixpkgs.overlays = [inputs.self.overlay];};
    nixosModules.hardware-configuration = ./hardware-configuration.nix;
    nixosModules.system-configuration = ./configuration.nix;

    nixosModules.home-manager = {pkgs, ...}: {
      home-manager.verbose = true;
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users."${username}".imports = [./home/default.nix];
    };

    nixosConfigurations.NVC3919 = inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = with inputs.self.nixosModules; [
        inputs.home-manager.nixosModules.home-manager
        hp-zbook-studio-g5
        overlays
        hardware-configuration
        system-configuration
        home-manager
      ];
    };

    devShell.${system} = pkgs.mkShell {
      nativeBuildInputs = with pkgs; [
        nixpkgs-fmt
      ];
    };
  };
}
