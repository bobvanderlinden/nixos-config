{ pkgs, ... }:
{ pkgs, lib, system, inputs }:
let
  mkPythonShell = { python }:
    with pkgs;
    mkShell {
      nativeBuildInputs = with pkgs; [
        python
        automake
        pkg-config
        virtualenv
      ];
      LD_LIBRARY_PATH = lib.makeLibraryPath [
        pkgs.stdenv.cc.cc.lib
      ];
    };
in
{
  python-3_11 =
    mkPythonShell {
      python = pkgs.python311;
    };

  python-3_10 =
    mkPythonShell {
      python = pkgs.python310;
    };

  python-3_8 =
    mkPythonShell {
      python = pkgs.python38;
    };

  python-3_7 =
    mkPythonShell {
      python = pkgs.python37;
    };

  python-2_7 = mkPythonShell {
    python = pkgs.python27;
  };
}
