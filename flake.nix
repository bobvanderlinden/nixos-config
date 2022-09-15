{
  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-22.05";
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

  outputs = inputs:
    let
      username = "bob.vanderlinden";
    in
    {
      overlays.default = final: prev: import ./packages { pkgs = final; };

      nixosModules =
        import ./system/modules
        // {
          overlays = { nixpkgs.overlays = [ inputs.self.overlays.default ]; };
          hardware-configuration = import ./system/hardware-configuration.nix;
          system-configuration = import ./system/configuration.nix;
          single-user = { suites.single-user.user = username; };
        };

      # System configuration for laptop.
      nixosConfigurations.NVC3919 = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = builtins.attrValues inputs.self.nixosModules;
      };

      homeConfigurations.${username} = inputs.home-manager.lib.homeManagerConfiguration {
        # A bit strange to specify pkgs with x86_64-linux here.
        # See https://github.com/nix-community/home-manager/issues/3075
        pkgs = import inputs.nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
          overlays = [
            inputs.self.overlays.default
          ];
        };
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
    // inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            inputs.self.overlays.default
          ];
        };
      in
      {
        packages = {
          inherit (pkgs)
            coin
            gnome-dbus-emulation-wlr
            immersed
            disable-firewall
            xrdesktop
            gxr
            gulkan
            wxrc
            wxrd;
        };

        devShells =
          (
            import ./dev-shells {
              # Use nixpkgs-stable for development shells.
              pkgs = import inputs.nixpkgs-stable {
                inherit system;
                config.allowUnfree = true;
              };
              inherit system inputs;
              inherit (inputs.nixpkgs) lib;
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
