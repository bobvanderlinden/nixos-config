{
  lib,
  stdenv,
  rustc,
}:

stdenv.mkDerivation {
  pname = "session-time";
  version = "0.1.0";

  src = ./.;

  buildInputs = [
    rustc
  ];

  buildPhase = ''
    rustc -O -o session-time main.rs
  '';

  installPhase = ''
    mkdir -p $out/bin
    install -m755 session-time $out/bin/session-time
  '';

  meta = {
    description = "A tool that displays time elapsed since a session was started";
    platforms = lib.platforms.all;
    mainProgram = "session-time";
  };
}
