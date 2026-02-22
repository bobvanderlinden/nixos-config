{
  writeShellApplication,
  opencode,
}:
writeShellApplication {
  name = "agent";
  text = builtins.readFile ./agent.sh;
  runtimeInputs = [
    opencode
  ];
}
