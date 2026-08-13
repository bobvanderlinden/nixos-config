{
  writeShellApplication,
  pi,
}:
writeShellApplication {
  name = "agent";
  text = builtins.readFile ./agent.sh;
  runtimeInputs = [
    pi
  ];
}
