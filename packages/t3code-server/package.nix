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
runCommand "t3code-server-${source.version}"
  {
    inherit (source) version;
    pname = "t3code-server";
    nativeBuildInputs = [ makeWrapper ];
    passthru = { inherit source; };
    meta = source.meta // {
      description = "T3 Code command-line server and web interface for coding agents";
      mainProgram = "t3";
    };
  }
  ''
    mkdir -p "$out/bin"
    makeWrapper ${lib.getExe' source "t3"} "$out/bin/t3" \
      --prefix PATH : ${
        lib.makeBinPath [
          pi-bolt
          git
          xdg-utils
        ]
      }

    mkdir -p "$out/share"
    for directory in bash-completion fish zsh; do
      if [ -d "${source}/share/$directory" ]; then
        ln -s "${source}/share/$directory" "$out/share/$directory"
      fi
    done

    "$out/bin/t3" --version | grep -F '${source.version}'
    "$out/bin/t3" --help > help.txt
    grep -q 'T3' help.txt
  ''
