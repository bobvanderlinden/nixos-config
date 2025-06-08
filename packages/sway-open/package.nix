{ writers, lib }:
let
  content = builtins.readFile ./sway-open.py;
in
writers.writePython3Bin "sway-open" { } content
