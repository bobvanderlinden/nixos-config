{
  nixConfig = {
    substituters = [
      "https://alejandra.cachix.org"
    ];
  };

  inputs.nixos-hardware = {
    url = "github:NixOS/nixos-hardware";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.alejandra.url = "github:kamadorueda/alejandra";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nixos-hardware,
    alejandra,
  }: let
    system = "x86_64-linux";
    username = "bob.vanderlinden";

    overlay = final: prev: {
      coin = final.callPackage ./packages/coin {};
      alejandra = alejandra.defaultPackage."${system}";
    };

    pkgs = import nixpkgs {
      inherit system;
      overlays = [overlay];
    };
  in rec {
    inherit overlay;

    homeManagerConfigurations."${username}" =
      home-manager.lib.homeManagerConfiguration {
        inherit system username;
        configuration = ./home/default.nix;
        homeDirectory = "/home/${username}";
      };

    nixosModules.hp-zbook-studio-g5 = {pkgs, ...}: {
      imports = [
        nixos-hardware.nixosModules.common-cpu-intel
        nixos-hardware.nixosModules.common-gpu-nvidia
        nixos-hardware.nixosModules.common-pc-laptop-ssd
        nixos-hardware.nixosModules.common-pc-laptop
      ];

      hardware.nvidia.prime.offload.enable = false;
      hardware.nvidia.powerManagement.enable = true;
      hardware.enableRedistributableFirmware = true;
      hardware.opengl.extraPackages = with pkgs; [
        vaapiVdpau
        libvdpau-va-gl
      ];
      hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [
        vaapiVdpau
        libvdpau-va-gl
      ];
    };

    nixosModules.home-manager = {pkgs, ...}: {
      home-manager.verbose = true;
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users."${username}".imports = [./home/default.nix];
    };

    nixosConfigurations.NVC3919 = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        {nixpkgs.overlays = [self.overlay];}
        self.nixosModules.hp-zbook-studio-g5
        ./hardware-configuration.nix
        ./configuration.nix
        home-manager.nixosModules.home-manager
        self.nixosModules.home-manager
      ];
    };

    devShell."${system}" = pkgs.mkShell {
      nativeBuildInputs = with pkgs; [
        alejandra
      ];
    };
  };
}
