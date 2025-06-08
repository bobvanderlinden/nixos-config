{ writers }:
let
  content = builtins.readFile ./hypr-open.py;
in
writers.writePython3Bin "hypr-open" { } content
