{
  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-22.05";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
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

    pkgs-stable = import inputs.nixpkgs-stable {
      inherit system;
      config.allowUnfree = true;
    };
  in rec {
    overlays.default = overlay;

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
      overlays = {nixpkgs.overlays = [inputs.self.overlays.default];};
      suite-single-user = import ./system/modules/suites/single-user.nix;
      suite-i3 = import ./system/modules/suites/i3.nix;
      suite-sway = import ./system/modules/suites/sway.nix;
      home-manager = import ./system/modules/home-manager.nix;
      hp-zbook-studio-g5 = import ./system/modules/hp-zbook-studio-g5.nix;
      hardware-configuration = import ./system/hardware-configuration.nix;
      system-configuration = import ./system/configuration.nix;
      single-user = {suites.single-user.user = username;};
    };

    nixosConfigurations.NVC3919 = inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs;
      };
      modules = builtins.attrValues inputs.self.nixosModules;
    };

    devShells.${system} =
      {
        default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            nixpkgs-fmt
          ];
        };
      }
      // (
        import ./shells {pkgs = pkgs-stable;}
      );
  };
}
