{
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
  };

  outputs = inputs: let
    system = "x86_64-linux";
    username = "bob.vanderlinden";

    overlay = final: prev: {
      coin = final.callPackage ./packages/coin {};
      git-worktree-shell = final.callPackage ./packages/git-worktree-shell {};
      gnome-dbus-emulation-wlr = final.callPackage ./packages/gnome-dbus-emulation-wlr {};
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
      inherit (pkgs) coin gnome-dbus-emulation-wlr;
    };

    homeConfigurations.${username} = inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./home
        {
          home.username = username;
          home.homeDirectory = "/home/${username}";
        }
      ];
    };

    nixosModules = {
      overlays = {nixpkgs.overlays = [inputs.self.overlay];};
      suite-single-user = ./system/modules/suites/single-user.nix;
      suite-i3 = ./system/modules/suites/i3.nix;
      suite-sway = ./system/modules/suites/sway.nix;
      home-manager = ./system/modules/home-manager.nix;
      hp-zbook-studio-g5 = ./system/modules/hp-zbook-studio-g5.nix;
      hardware-configuration = ./system/hardware-configuration.nix;
      system-configuration = ./system/configuration.nix;
    };

    nixosConfigurations.NVC3919 = inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs;
      };
      modules = with inputs.self.nixosModules; [
        suite-single-user
        suite-i3
        suite-sway
        hp-zbook-studio-g5
        overlays
        hardware-configuration
        system-configuration
        home-manager
        {suites.single-user.user = username;}
      ];
    };

    devShell.${system} = pkgs.mkShell {
      nativeBuildInputs = with pkgs; [
        nixpkgs-fmt
      ];
    };
  };
}
