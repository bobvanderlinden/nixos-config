{
  lib,
  callPackage,
  runCommand,
  makeWrapper,
  pi-bolt,
  git,
  xdg-utils,
}:
let
  source = callPackage ../t3code-source.nix { };
in
runCommand "t3code-desktop-${source.version}"
  {
    inherit (source) version;
    pname = "t3code-desktop";
    nativeBuildInputs = [ makeWrapper ];
    passthru = { inherit source; };
    meta = source.meta // {
      description = "T3 Code desktop interface for coding agents";
      mainProgram = "t3code-desktop";
    };
  }
  ''
    mkdir -p "$out/bin"
    makeWrapper ${lib.getExe' source "t3code-desktop"} "$out/bin/t3code-desktop" \
      --prefix PATH : ${
        lib.makeBinPath [
          pi-bolt
          git
          xdg-utils
        ]
      }

    mkdir -p "$out/share"
    ln -s ${source}/share/applications "$out/share/applications"
    ln -s ${source}/share/icons "$out/share/icons"
  ''
