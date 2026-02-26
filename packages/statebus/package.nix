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

  virtualenv = pythonSet.mkVirtualEnv "statebus-env" workspace.deps.default;

  inherit (pkgs.callPackages pyproject-nix.build.util { }) mkApplication;
in
mkApplication {
  venv = virtualenv;
  package = pythonSet.statebus;
}
