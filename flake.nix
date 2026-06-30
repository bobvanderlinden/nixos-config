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
    networkmanager-openvpn3 = {
      url = "github:bobvanderlinden/NetworkManager-openvpn3";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impurity = {
      url = "github:outfoxxed/impurity.nix";
    };
    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
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

      username = "bob.vanderlinden";
      defaultOverlays = [
        self.overlays.default
        self.overlays.workarounds
        self.overlays.pyproject
        self.overlays.quickshell
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
      nixosSystem = import (inputs.nixpkgs + "/nixos/lib/eval-config.nix");
    in
    {
      overlays.default =
        final: prev:
        (prev.lib.packagesFromDirectoryRecursive {
          inherit (final) callPackage;
          directory = ./packages;
        })
        // {
          "3dmmex" = final.callPackage ./packages/3dmmex/package.nix { };
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
          # Upgrade opencode to v1.17.11 ahead of nixpkgs.
          # opencode v1.17.11 pins bun@1.3.14, while nixpkgs ships 1.3.13.
          # Use a scoped bun bump so the frozen lockfile validates.
          opencode =
            let
              bun_1_3_14 = prev.bun.overrideAttrs (oldBun: rec {
                version = "1.3.14";
                src = prev.fetchurl {
                  url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-x64.zip";
                  hash = "sha256-lR7iruhV8IWVruxiJSJqKY0/6oOj3NZGXAnLzN9+hI8=";
                };
              });
            in
            (prev.opencode.override { bun = bun_1_3_14; }).overrideAttrs (oldAttrs: rec {
              version = "1.17.11";
              src = prev.fetchFromGitHub {
                owner = "anomalyco";
                repo = "opencode";
                tag = "v${version}";
                hash = "sha256-ZgmRHoI3rxsSM10sA4cZu/FxqwmgawQvlW3eykXQsqQ=";
              };
              node_modules = oldAttrs.node_modules.overrideAttrs (oldNm: {
                inherit version src;
                # opencode's committed bun.lock doesn't validate under
                # --frozen-lockfile; drop it (bun is pinned to 1.3.14 so
                # resolution stays deterministic, fixed by outputHash).
                buildPhase = builtins.replaceStrings [ "--frozen-lockfile " ] [ "" ] oldNm.buildPhase;
                outputHash = "sha256-PhFDNxeJHTQdT8mAJz7hVKnsUL3Ez6NSgnUSMz3LUqY=";
              });
              env = oldAttrs.env // {
                OPENCODE_VERSION = version;
              };
              # v1.17.11's build.ts runs a smoke test (opencode --version) that
              # segfaults inside the sandbox. Disable it; the version check hook
              # still validates the final wrapped binary post-build.
              postPatch = (oldAttrs.postPatch or "") + ''
                substituteInPlace packages/opencode/script/build.ts \
                  --replace-fail 'item.os === process.platform' 'false && item.os === process.platform'
              '';
              # `opencode completion` returns nothing in v1.17.11, breaking
              # installShellCompletion. Skip it until nixpkgs catches up.
              postInstall = "";
            });

          # pasystray = prev.pasystray.overrideAttrs (prevAttrs: {
          #   patches = (prevAttrs.patches or [ ]) ++ [
          #     (prev.fetchpatch {
          #       url = "https://github.com/christophgysin/pasystray/pull/183.patch";
          #       hash = "sha256-BQ10LddqE3XwUeRklZE3S3+KOjJ9BtfddaFswgUqZ5g=";
          #     })
          #   ];
          # });

          fwupd = prev.fwupd.overrideAttrs (oldAttrs: {
            postPatch = (oldAttrs.postPatch or "") + ''
              substituteInPlace libfwupdplugin/fu-path-store.c \
                --replace-fail \
                  '{"FWUPD_LIBDIR_PKG", FU_PATH_KIND_LIBDIR_PKG},' \
                  '{"FWUPD_LIBDIR_PKG", FU_PATH_KIND_LIBDIR_PKG}, {"FWUPD_EFIAPPDIR", FU_PATH_KIND_EFIAPPDIR},'
            '';
          });
        };

      overlays.quickshell = final: _prev: {
        quickshell = inputs.quickshell.packages.${final.stdenv.hostPlatform.system}.default;
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
        impurity-home-manager = {
          home-manager.sharedModules = [
            inputs.impurity.nixosModules.default
            {
              impurity.configRoot = self;
              impurity.enable = builtins.getEnv "IMPURITY_PATH" != "";
            }
          ];
        };
        networkmanager-openvpn3 = inputs.networkmanager-openvpn3.nixosModules.default;
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
        checks = pkgs.lib.optionalAttrs (system == "x86_64-linux") {
          greetd-autologin-keyring = pkgs.testers.runNixOSTest (
            import ./tests/greetd-autologin-keyring.nix {
              lib = pkgs.lib;
              inherit pkgs;
              greetdAutologinKeyringModule = self.nixosModules."greetd-autologin-keyring";
            }
          );
        };

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
                  IMPURITY_PATH="$(pwd)"
                  export IMPURITY_PATH
                  nom build --impure --keep-going --out-link home-result ${self}#nixosConfigurations."$(hostname)".config.home-manager.users.\""$USER"\".home.activationPackage
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
                  IMPURITY_PATH="$(pwd)"
                  export IMPURITY_PATH
                  nom build --impure --keep-going --out-link system-result ${self}#nixosConfigurations."$(hostname)".config.system.build.toplevel
                  nom build --impure --keep-going --out-link home-result ${self}#nixosConfigurations."$(hostname)".config.home-manager.users.\""$USER"\".home.activationPackage
                  if [[ "$(readlink --canonicalize system-result)" != "$(readlink --canonicalize /nix/var/nix/profiles/system)" ]]
                  then
                    ${pkgs.coin}/bin/coin
                    pkexec sh -c "nix-env -p /nix/var/nix/profiles/system --set \"$(readlink system-result)\" && $(readlink system-result)/bin/switch-to-configuration switch"
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
