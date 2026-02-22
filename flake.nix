{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    lanzaboote.url = "github:nix-community/lanzaboote";
    nix-index-database.url = "github:nix-community/nix-index-database";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    voxtype = {
      url = "github:peteonrails/voxtype";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://install.determinate.systems"
    ];
    extra-trusted-public-keys = [
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
    ];
  };

  outputs =
    {
      self,
      flake-utils,
      lanzaboote,
      nix-index-database,
      sops-nix,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      # We'd like to be able to add patches on top of nixpkgs, like pending pull requests.
      # Source: https://github.com/NixOS/nixpkgs/pull/142273#issuecomment-948225922
      patchedNixpkgs =
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        pkgs.applyPatches {
          name = "nixpkgs-patched";
          src = inputs.nixpkgs;
          patches = [
            # (pkgs.fetchurl {
            #   url = "https://github.com/NixOS/nixpkgs/pull/474174.patch";
            #   hash = "sha256-z9760cR8MA+gmYCssPRpIDA8bvteh5cr3gSttHmzA1g=";
            # })
          ];
        };
      username = "bob.vanderlinden";
      defaultOverlays = [
        self.overlays.default
        self.overlays.workarounds
        self.overlays.pyproject
      ];
      mkPkgs =
        {
          system ? system,
          nixpkgs ? patchedNixpkgs,
          config ? {
            allowUnfree = true;
          },
          overlays ? defaultOverlays,
          ...
        }@options:
        import nixpkgs (options // { inherit system config overlays; });
      nixosSystem = import (patchedNixpkgs + "/nixos/lib/eval-config.nix");
    in
    {
      overlays.default =
        final: prev:
        prev.lib.packagesFromDirectoryRecursive {
          inherit (final) callPackage;
          directory = ./packages;
        };
      overlays.pyproject = _final: _prev: {
        inherit pyproject-nix uv2nix pyproject-build-systems;
      };

      overlays.workarounds =
        final: prev:
        # let
        #   pkgsStable = import inputs.nixpkgs-stable {
        #     system = prev.system;
        #     config.allowUnfree = true;
        #   };
        # in
        {
          # pasystray = prev.pasystray.overrideAttrs (prevAttrs: {
          #   patches = (prevAttrs.patches or [ ]) ++ [
          #     (prev.fetchpatch {
          #       url = "https://github.com/christophgysin/pasystray/pull/183.patch";
          #       hash = "sha256-BQ10LddqE3XwUeRklZE3S3+KOjJ9BtfddaFswgUqZ5g=";
          #     })
          #   ];
          # });
        };

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
        inherit (sops-nix.nixosModules) sops;
        determinate = inputs.determinate.nixosModules.default;
        # inherit (nix-index-database.nixosModules) nix-index;
        nix-index-database-home-manager = {
          home-manager.sharedModules = [ nix-index-database.homeModules.nix-index ];
        };
        voxtype-home-manager = {
          home-manager.sharedModules = [ inputs.voxtype.homeManagerModules.default ];
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
        self.nixosConfigurations.nac44250.config.home-manager.users.${username}.home
        // {
          config = self.nixosConfigurations.nac44250.config.home-manager.users.${username};
        };
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
            inherit (builtins) attrNames;
            inherit (pkgs.lib) genAttrs filterAttrs;
            # We're going to use overlays.default to create an attrbute set of my packages.
            packageOverlay = self.overlays.default;
            # We extract the package names from the overlay without actually applying it (which would result in _all_ packages)
            # We'll use these names to extract the custom packages from pkgs
            packageNames =
              let
                fakePrev = { inherit (pkgs) callPackage; };
                fakeFinal = { inherit (pkgs) lib; };
              in
              attrNames (packageOverlay fakePrev fakeFinal);
            # finalPkgs contain _all_ packages (those from packageOverlay as well as all of nixpkgs), we need to pick those defined in packageOverlay.
            finalPackages = genAttrs packageNames (packageName: pkgs.${packageName});
            # Filter packages that are not compatible with the current system
            compatiblePackages = filterAttrs (
              name: package:
              (package ? meta) -> (package.meta ? platforms) -> builtins.elem system package.meta.platforms
            ) finalPackages;
          in
          compatiblePackages;

        apps.switch-home = {
          type = "app";
          program =
            let
              switch-home = pkgs.writeShellApplication {
                name = "switch-home";
                text = ''
                  nom build --keep-going --out-link home-result ${self}#nixosConfigurations."$(hostname)".config.home-manager.users.\""$USER"\".home.activationPackage
                  ./home-result/activate
                '';
                runtimeInputs = [ pkgs.nix-output-monitor ];
              };
            in
            "${switch-home}/bin/switch-home";
        };

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

        formatter = pkgs.nixfmt-tree;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nixfmt
            nixd
            kubeseal
          ];
        };
      }
    );
}
