{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-ruby = {
      url = "github:bobvanderlinden/nixpkgs-ruby";
    };
    lanzaboote.url = "github:nix-community/lanzaboote";
    nix-index-database.url = "github:nix-community/nix-index-database";
  };

  outputs = { self, nixpkgs, home-manager, flake-utils, lanzaboote, nix-index-database, ... } @ inputs:
    let
      username = "bob.vanderlinden";
      defaultOverlays = with self.overlays; [ default workarounds ];
      mkPkgs =
        { system ? "x86_64-linux"
        , nixpkgs ? inputs.nixpkgs
        , config ? { allowUnfree = true; }
        , overlays ? defaultOverlays
        , ...
        } @ options: import nixpkgs (options // {
          inherit system config overlays;
        });
    in {
      overlays.default = final: prev: import ./packages { pkgs = final; };
      overlays.workarounds = final: prev: {
        # Workaround build failure: https://github.com/NixOS/nixpkgs/issues/298150
        fprintd = prev.fprintd.overrideAttrs {
          mesonCheckFlags = [
            "--no-suite"
            "fprintd:TestPamFprintd"
          ];
        };
      };

      nixosModules =
        import ./system/modules
        // {
          overlays = { nixpkgs.overlays = defaultOverlays; };
          hardware-configuration = import ./system/hardware-configuration.nix;
          system-configuration = import ./system/configuration.nix;
          single-user = { suites.single-user.user = username; };
          inherit (lanzaboote.nixosModules) lanzaboote;
          # inherit (nix-index-database.nixosModules) nix-index;
          nix-index-database-home-manager = { home-manager.sharedModules = [ nix-index-database.hmModules.nix-index ]; };
        };

      # System configuration for laptop.
      nixosConfigurations.nac44250 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = builtins.attrValues self.nixosModules;
      };

      homeConfigurations."${username}@nac44250" = self.nixosConfigurations.nac44250.config.home-manager.users.${username}.home;

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
            lib = pkgs.lib;
          in
          lib.filterAttrs (name: package: (package ? meta) -> (package.meta ? platforms) -> builtins.elem system package.meta.platforms) (import ./packages { inherit pkgs; });

        apps.switch = {
          type = "app";
          program = let
            switch = pkgs.writeShellApplication {
              name = "switch";
              text = ''
                nom build --impure --keep-going --out-link system-result ${self}#nixosConfigurations."$(hostname)".config.system.build.toplevel
                nom build --keep-going --out-link home-result ${self}#nixosConfigurations."$(hostname)".config.home-manager.users.\""$USER"\".home.activationPackage
                ./home-result/activate
                ${pkgs.coin}/bin/coin
                sudo nix-env -p /nix/var/nix/profiles/system --set "$(readlink system-result)"
                sudo system-result/bin/switch-to-configuration switch
              '';
              runtimeInputs = [ pkgs.nix-output-monitor ];
            };
          in "${switch}/bin/switch";
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            nixpkgs-fmt
            nixd
          ];
        };
      });
}
