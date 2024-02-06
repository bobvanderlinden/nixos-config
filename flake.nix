{
  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-ruby = {
      url = "github:bobvanderlinden/nixpkgs-ruby";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
  };

  outputs = { self, nixpkgs, home-manager, flake-utils, nixpkgs-stable, ... } @ inputs:
    let
      username = "bob.vanderlinden";
      mkPkgs =
        { system ? "x86_64-linux"
        , nixpkgs ? inputs.nixpkgs
        , config ? { allowUnfree = true; }
        , overlays ? [ self.overlays.default ]
        , ...
        } @ options: import nixpkgs (options // {
          inherit system config overlays;
        });
    in
    {
      overlays.default = final: prev: import ./packages { pkgs = final; };

      nixosModules =
        import ./system/modules
        // {
          overlays = { nixpkgs.overlays = [ self.overlays.default ]; };
          hardware-configuration = import ./system/hardware-configuration.nix;
          system-configuration = import ./system/configuration.nix;
          single-user = { suites.single-user.user = username; };
        };

      # System configuration for laptop.
      nixosConfigurations.nac44250 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = builtins.attrValues self.nixosModules;
      };

      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        # A bit strange to specify pkgs with x86_64-linux here.
        # See https://github.com/nix-community/home-manager/issues/3075
        pkgs = mkPkgs { };
        modules = [
          ./home
          {
            home.username = username;
            home.homeDirectory = "/home/${username}";
          }
        ];
      };

      templates = import ./templates;
    }
    # Define outputs that allow multiple systems with for all default systems.
    # This is to support OSX and RPI.
    // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = mkPkgs {
          inherit system;
        };
      in
      {
        packages =
          let
            lib = nixpkgs.lib;
          in
          lib.filterAttrs (name: package: (package ? meta) -> (package.meta ? platforms) -> builtins.elem system package.meta.platforms) (import ./packages { inherit pkgs; });

        devShells =
          (
            import ./dev-shells {
              # Use nixpkgs-stable for development shells.
              pkgs = mkPkgs {
                nixpkgs = nixpkgs-stable;
                inherit system;
                overlays = [ ];
              };
              inherit system inputs;
              inherit (nixpkgs-stable) lib;
            }
          )
          // {
            # The shell for editing this project.
            default = pkgs.mkShell {
              nativeBuildInputs = with pkgs; [
                nixpkgs-fmt
              ];
            };
          };
      });
}
