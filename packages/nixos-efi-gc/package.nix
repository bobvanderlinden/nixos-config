{ writers }:
let
  content = builtins.readFile ./nixos-efi-gc.py;
in
writers.writePython3Bin "nixos-efi-gc" { } content
