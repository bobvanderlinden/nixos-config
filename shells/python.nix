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

      ] ++ lib.optional pkgs.stdenv.isLinux [
        chromedriver
      ];
      WD_CHROME_PATH = lib.optionalString pkgs.stdenv.isLinux "${pkgs.chromium}/bin/chromium";
      FREEDESKTOP_MIME_TYPES_PATH = "${pkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml";
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
