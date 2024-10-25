{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    lanzaboote.url = "github:nix-community/lanzaboote";
    nix-index-database.url = "github:nix-community/nix-index-database";
  };

  outputs =
    {
      self,
      flake-utils,
      lanzaboote,
      nix-index-database,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      # We'd like to be able to add patches on top of nixpkgs, like pending pull requests.
      # Source: https://github.com/NixOS/nixpkgs/pull/142273#issuecomment-948225922
      nixpkgs =
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        pkgs.applyPatches {
          name = "nixpkgs-patched";
          src = inputs.nixpkgs;
          patches = [
            # Fix openvpn3 glibc incompatibility.
            (pkgs.fetchpatch {
              url = "https://github.com/NixOS/nixpkgs/pull/326623.patch";
              hash = "sha256-ziop85PodXV4u3zLbXSQc03xagPIbZx7fCGdFkHLl7Y=";
            })
          ];
        };
      username = "bob.vanderlinden";
      defaultOverlays = with self.overlays; [
        default
        workarounds
      ];
      mkPkgs =
        {
          system ? system,
          nixpkgs ? inputs.nixpkgs,
          config ? {
            allowUnfree = true;
          },
          overlays ? defaultOverlays,
          ...
        }@options:
        import nixpkgs (options // { inherit system config overlays; });
      nixosSystem = import (nixpkgs + "/nixos/lib/eval-config.nix");
    in
    {
      overlays.default = final: prev: import ./packages { pkgs = final; };
      overlays.workarounds = final: prev: { };

      nixosModules = import ./system/modules // {
        overlays = {
          nixpkgs.overlays = defaultOverlays;
        };
        hardware-configuration = import ./system/hardware-configuration.nix;
        system-configuration = import ./system/configuration.nix;
        single-user = {
          suites.single-user.user = username;
        };
        inherit (lanzaboote.nixosModules) lanzaboote;
        # inherit (nix-index-database.nixosModules) nix-index;
        nix-index-database-home-manager = {
          home-manager.sharedModules = [ nix-index-database.hmModules.nix-index ];
        };
      };

      # System configuration for laptop.
      nixosConfigurations.nac44250 = nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
        };
        modules = builtins.attrValues self.nixosModules;
      };

      homeConfigurations."${username}@nac44250" =
        self.nixosConfigurations.nac44250.config.home-manager.users.${username}.home;
    }
    # Define outputs that allow multiple systems with for all default systems.
    # This is to support OSX and RPI.
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = mkPkgs { inherit system; };
      in
      {
        packages =
          let
            lib = pkgs.lib;
          in
          lib.filterAttrs (
            name: package:
            (package ? meta) -> (package.meta ? platforms) -> builtins.elem system package.meta.platforms
          ) (import ./packages { inherit pkgs; });

        apps.switch = {
          type = "app";
          program =
            let
              switch = pkgs.writeShellApplication {
                name = "switch";
                text = ''
                  nom build --impure --keep-going --out-link system-result ${self}#nixosConfigurations."$(hostname)".config.system.build.toplevel
                  nom build --keep-going --out-link home-result ${self}#nixosConfigurations."$(hostname)".config.home-manager.users.\""$USER"\".home.activationPackage
                  if [[ "$(readlink --canonicalize system-result)" != "$(readlink --canonicalize /nix/var/nix/profiles/system)" ]]
                  then
                    ${pkgs.coin}/bin/coin
                    sudo nix-env -p /nix/var/nix/profiles/system --set "$(readlink system-result)"
                    sudo system-result/bin/switch-to-configuration switch
                  fi
                  ./home-result/activate
                '';
                runtimeInputs = [ pkgs.nix-output-monitor ];
              };
            in
            "${switch}/bin/switch";
        };

        formatter = {
          type = "app";
          program = "${pkgs.nixfmt-rfc-style}/bin/nixfmt";
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nixfmt-rfc-style
            nixd
          ];
        };
      }
    );
}
