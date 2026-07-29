{
  lib,
  pkgs,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
}:
let
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  python = pkgs.python3;

  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages {
      inherit python;
    }).overrideScope
      (
        lib.composeManyExtensions [
          pyproject-build-systems.overlays.default
          overlay
        ]
      );

  virtualenv = pythonSet.mkVirtualEnv "semble-env" workspace.deps.default;

  sembleSource =
    pkgs.runCommand "semble-${pythonSet.semble.version}-source"
      {
        src = pkgs.fetchurl {
          inherit (pythonSet.semble.package.sdist) url;
          hash = "sha256-s1eoWMixDKTO51VFtvJ+FuekF6uPwlHZBcgYLxcXycc=";
        };
      }
      ''
        mkdir --parents $out
        tar --extract --gzip --file $src --strip-components=1 --directory $out
      '';

  inherit (pkgs.callPackages pyproject-nix.build.util { }) mkApplication;
in
(mkApplication {
  venv = virtualenv;
  package = pythonSet.semble;
}).overrideAttrs
  (oldAttrs: {
    passthru = (oldAttrs.passthru or { }) // {
      src = sembleSource;
    };
  })
