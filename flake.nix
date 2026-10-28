{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    lanzaboote.url = "github:nix-community/lanzaboote";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database.url = "github:nix-community/nix-index-database";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impurity = {
      url = "github:outfoxxed/impurity.nix";
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
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    scrolloverview = {
      url = "github:yayuuu/hyprland-scroll-overview";
      flake = false;
    };
    unisic = {
      url = "github:unisic/unisic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://install.determinate.systems"
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
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
            # Fix Hyprland 0.57.0 requiring hyprutils >= 0.14.3.
            # Source: https://github.com/NixOS/nixpkgs/pull/579528
            (pkgs.fetchpatch {
              url = "https://github.com/NixOS/nixpkgs/commit/f78cc1dd16e79d32f063097c51c5593c3d9cdb86.patch";
              hash = "sha256-XzT06TTtCJ87ikdW+eY7CmbEoxBlm1bfLsllvNN3gw0=";
            })
            # Upgrade Hyprland and its official plugins to 0.57.0, with rtkit scheduling.
            # Source: https://github.com/NixOS/nixpkgs/pull/580006
            (pkgs.fetchurl {
              name = "hyprland-0.57.0.patch";
              url = "https://github.com/NixOS/nixpkgs/compare/3e80146184cb3453db3423c422665335e9361e2f...48bba164e8d7eea5b1c9fbc420094a9d6f2f9946.patch";
              hash = "sha256-Vq58AeKq9ttpWl2IYrJmFDCar+urW4OdIb2pFAgAGO0=";
            })
            # Fix Azure CLI evaluation failing because Fabric requires Invoke < 3.
            # Source: https://github.com/NixOS/nixpkgs/commit/2415b61e7d6cf34170f3e75c2a68928434817f11.patch
            (pkgs.fetchpatch {
              url = "https://github.com/NixOS/nixpkgs/commit/2415b61e7d6cf34170f3e75c2a68928434817f11.patch";
              hash = "sha256-6Cs+lB2337d10FmjKm/CqrRVpkdp7yz0aIqv2x/YfF8=";
            })
            # Fix 1Password 8.12.42 failing to load libglib-2.0.so.0 in its crash handler.
            # Source: https://github.com/NixOS/nixpkgs/pull/579025
            (pkgs.fetchpatch {
              url = "https://github.com/NixOS/nixpkgs/commit/ce4e383d1929094aba0723ba127e1ada5e885ac5.patch";
              hash = "sha256-Q4GJgLMJ7CEc630i3ecl7Qg1GaEnmBdFLP8oYPAO8hI=";
            })
          ];
        };

      username = "bob.vanderlinden";
      collectNixModules =
        directory:
        let
          entries = builtins.readDir directory;
        in
        builtins.concatMap (
          name:
          let
            type = entries.${name};
            defaultModule = directory + "/${name}/default.nix";
          in
          if type == "regular" && builtins.match ".*\\.nix" name != null then
            [ (directory + "/${name}") ]
          else if type == "directory" && builtins.pathExists defaultModule then
            [ (directory + "/${name}") ]
          else
            [ ]
        ) (builtins.attrNames entries);
      systemModulePaths = collectNixModules ./system/modules;
      systemNixosModules = builtins.listToAttrs (
        builtins.map (modulePath: {
          name = inputs.nixpkgs.lib.removeSuffix ".nix" (builtins.baseNameOf modulePath);
          value = import modulePath;
        }) systemModulePaths
      );
      defaultOverlays = [
        self.overlays.llm-agents
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
      commonLaptopModules = [
        self.nixosModules.overlays
        self.nixosModules.single-user
        self.nixosModules."suite-single-user"
        self.nixosModules."suite-nix-channels"
        self.nixosModules.home-manager
        self.nixosModules.lanzaboote
        self.nixosModules.determinate
        self.nixosModules.nix-index-database-home-manager
        self.nixosModules.impurity-home-manager
      ];
      mkLaptop =
        hostModule: homeProfile: extraModules:
        nixosSystem {
          inherit system;
          specialArgs = { inherit inputs collectNixModules; };
          modules =
            commonLaptopModules
            ++ [
              ./system/profiles/laptop.nix
              hostModule
              {
                home-manager.users.${username}.imports = [ homeProfile ];
              }
            ]
            ++ extraModules;
        };
    in
    {
      overlays.llm-agents =
        final: _prev:
        let
          packages = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system};
        in
        {
          inherit (packages) semble;
        };

      overlays.default =
        final: _prev:
        let
          packageEntries = builtins.readDir ./packages;
          packageNames = builtins.filter (
            name:
            packageEntries.${name} == "directory" && builtins.pathExists (./packages + "/${name}/package.nix")
          ) (builtins.attrNames packageEntries);
          packages = builtins.listToAttrs (
            builtins.map (name: {
              inherit name;
              value = final.callPackage (./packages + "/${name}/package.nix") { };
            }) packageNames
          );
        in
        packages
        // {
          scrolloverview = final.callPackage ./packages/scrolloverview/package.nix {
            src = inputs.scrolloverview;
          };
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

          fwupd = prev.fwupd.overrideAttrs (oldAttrs: {
            postPatch = (oldAttrs.postPatch or "") + ''
              substituteInPlace libfwupdplugin/fu-path-store.c \
                --replace-fail \
                  '{"FWUPD_LIBDIR_PKG", FU_PATH_KIND_LIBDIR_PKG},' \
                  '{"FWUPD_LIBDIR_PKG", FU_PATH_KIND_LIBDIR_PKG}, {"FWUPD_EFIAPPDIR", FU_PATH_KIND_EFIAPPDIR},'
            '';
          });

        };

      nixosModules = systemNixosModules // {
        workarounds = {
          # python3.14-fabric-3.2.3 is broken as part of azure-cli
          problems.handlers = {
            fabric.broken = "warn";
          };
        };
        overlays = {
          nixpkgs.overlays = defaultOverlays;
        };
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
      };

      nixosConfigurations = {
        nac44250 = mkLaptop ./system/nac44250.nix ./home/profiles/machines/nac44250.nix [ ];
        nac54003 = mkLaptop ./system/nac54003.nix ./home/profiles/machines/nac54003.nix [
          inputs.disko.nixosModules.disko
          ./system/profiles/localllm.nix
        ];
      };

      homeConfigurations = builtins.listToAttrs (
        builtins.map (hostname: {
          name = "${username}@${hostname}";
          value = self.nixosConfigurations.${hostname}.config.home-manager.users.${username}.home // {
            config = self.nixosConfigurations.${hostname}.config.home-manager.users.${username};
          };
        }) (builtins.attrNames self.nixosConfigurations)
      );
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

        apps.install-nixos = {
          type = "app";
          program = "${pkgs.install-nixos}/bin/install-nixos";
        };

        apps.switch-home = {
          type = "app";
          program =
            let
              switch-home = pkgs.writeShellApplication {
                name = "switch-home";
                text = ''
                  if [[ "''${1-}" == "--plain" ]]
                  then
                    build=(nix build --log-format raw)
                    shift
                  elif [[ $# -eq 0 ]]
                  then
                    build=(nom build)
                  else
                    echo "Usage: switch-home [--plain]" >&2
                    exit 2
                  fi

                  IMPURITY_PATH="$(pwd)"
                  export IMPURITY_PATH
                  HOSTNAME="''${HOSTNAME-$(hostname)}"
                  "''${build[@]}" --impure --keep-going --out-link home-result ${self}#nixosConfigurations."$HOSTNAME".config.home-manager.users.\""$USER"\".home.activationPackage
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
                  if [[ "''${1-}" == "--plain" ]]
                  then
                    build=(nix build --log-format raw)
                    shift
                  elif [[ $# -eq 0 ]]
                  then
                    build=(nom build)
                  else
                    echo "Usage: switch [--plain]" >&2
                    exit 2
                  fi

                  IMPURITY_PATH="$(pwd)"
                  export IMPURITY_PATH
                  HOSTNAME="''${HOSTNAME-$(hostname)}"
                  # Build both targets together so Nix evaluates the shared NixOS configuration once.
                  # `nix build --out-link system-result` names the second result system-result-1.
                  "''${build[@]}" --impure --keep-going --out-link system-result \
                    ${self}#nixosConfigurations."$HOSTNAME".config.system.build.toplevel \
                    ${self}#nixosConfigurations."$HOSTNAME".config.home-manager.users.\""$USER"\".home.activationPackage
                  ln --symbolic --force --no-target-directory "$(readlink system-result-1)" home-result
                  if [[ "$(readlink --canonicalize system-result)" != "$(readlink --canonicalize /nix/var/nix/profiles/system)" ]]
                  then
                    ${pkgs.coin}/bin/coin
                    system_result="$(readlink system-result)"
                    switch_system_command="nix-env -p /nix/var/nix/profiles/system --set \"$system_result\" && \"$system_result/bin/switch-to-configuration\" switch"
                    if [[ -e /run/wrappers/bin/pkexec ]]
                    then
                      /run/wrappers/bin/pkexec ${pkgs.runtimeShell} -c "$switch_system_command"
                    else
                      /run/wrappers/bin/sudo ${pkgs.runtimeShell} -c "$switch_system_command"
                    fi
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
