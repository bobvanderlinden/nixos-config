{
  writeShellApplication,
  coreutils,
}:
writeShellApplication {
  name = "generate-password";
  text = builtins.readFile ./generate-password.sh;
  runtimeInputs = [
    coreutils
  ];
}
