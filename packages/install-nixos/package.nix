{
  coreutils,
  disko,
  findutils,
  gnugrep,
  gnused,
  gawk,
  jq,
  nix-output-monitor,
  shadow,
  util-linux,
  writeShellApplication,
}:
let
  flakeSource = ../..;
in
writeShellApplication {
  name = "install-nixos";
  runtimeInputs = [
    coreutils
    disko
    findutils
    gnugrep
    gnused
    gawk
    jq
    nix-output-monitor
    shadow
    util-linux
  ];
  text = builtins.replaceStrings [ "@flakeSource@" ] [ "${flakeSource}" ] (
    builtins.readFile ./install-nixos.sh
  );
}
