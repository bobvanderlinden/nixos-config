{
  writeShellApplication,
  coreutils,
}:
writeShellApplication {
  name = "adhoc";
  text = builtins.readFile ./adhoc.sh;
  runtimeInputs = [
    coreutils
  ];
}
