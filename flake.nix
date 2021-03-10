{
  inputs.nixos-hardware = {
    url = "github:NixOS/nixos-hardware";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.nixpkgs.url = "/home/bob.vanderlinden/projects/nixpkgs";
  outputs = { self, nixpkgs, home-manager, nixos-hardware }: rec {
    overlay = final: prev: { coin = final.callPackage ./packages/coin { }; };
    nixosModules.hp-zbook-studio-g5 = { pkgs, ... }: {
      imports = [
        nixos-hardware.nixosModules.common-cpu-intel
        nixos-hardware.nixosModules.common-gpu-nvidia
        nixos-hardware.nixosModules.common-pc-laptop-ssd
        nixos-hardware.nixosModules.common-pc-laptop
      ];

      hardware.nvidia.prime.offload.enable = false;
      hardware.enableRedistributableFirmware = true;
      hardware.opengl.extraPackages = [ pkgs.libvdpau-va-gl ];
      hardware.opengl.extraPackages32 = [ pkgs.pkgsi686Linux.libvdpau-va-gl ];
    };
    nixosConfigurations.NVC3919 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        { nixpkgs.overlays = [ self.overlay ]; }
        self.nixosModules.hp-zbook-studio-g5
        ./hardware-configuration.nix
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.verbose = true;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users."bob.vanderlinden".imports = [ ./home.nix ];
        }
      ];
    };
  };
}
