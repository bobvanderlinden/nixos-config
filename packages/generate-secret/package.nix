{
  writeShellApplication,
  coreutils,
}:
writeShellApplication {
  name = "generate-secret";
  text = builtins.readFile ./generate-secret.sh;
  runtimeInputs = [
    coreutils
  ];
}
