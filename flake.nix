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
      patchedNixpkgs =
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        pkgs.applyPatches {
          name = "nixpkgs-patched";
          src = inputs.nixpkgs;
          patches = [
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
      overlays.default = final: prev: import ./packages { pkgs = final; };
      overlays.workarounds =
        final: prev:
        # let
        #   pkgsStable = import inputs.nixpkgs-stable {
        #     system = prev.system;
        #     config.allowUnfree = true;
        #   };
        # in
        {
          # Downgrade 1password-gui to 8.10.40, as 8.10.44+ has a problem with the CLI.
          # See: https://github.com/NixOS/nixpkgs/issues/373415
          _1password-gui =
            let
              version = "8.10.40";
            in
            prev._1password-gui.overrideAttrs (prevAttrs: {
              inherit version;
              src = final.fetchurl {
                url = "https://downloads.1password.com/linux/tar/stable/x86_64/1password-${version}.x64.tar.gz";
                hash = "sha256-viY0SOUhrOvmue6Nolau356rIqwDo2nLzMilFFmNb9g=";
              };
            });
          # _1password = _1passwordPkgs._1password;

          # Pin zoom-us to avoid continuous breaking changes.
          # Latest one: https://github.com/NixOS/nixpkgs/issues/371488
          # zoom-us =
          #   let
          #     version = "6.3.5.6065";
          #   in
          #   prev.zoom-us.overrideAttrs (prevAttrs: {
          #     inherit version;
          #     src = final.fetchurl {
          #       url = "https://zoom.us/client/${version}/zoom_x86_64.pkg.tar.xz";
          #       hash = "sha256-JOkQsiYWcVq3LoMI2LyMZ1YXBtiAf612T2bdbduqry8=";
          #     };
          #   });
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
          lib.filterAttrs
            (
              name: package:
              (package ? meta) -> (package.meta ? platforms) -> builtins.elem system package.meta.platforms
            )
            (
              (import ./packages { inherit pkgs; })
              // {
                # zoom-us = pkgs.zoom-us;
              }
            );

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
            nixfmt-rfc-style
            nixd
          ];
        };
      }
    );
}
