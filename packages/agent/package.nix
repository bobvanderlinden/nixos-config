{
  writeShellApplication,
  pi-coding-agent,
}:
writeShellApplication {
  name = "agent";
  text = builtins.readFile ./agent.sh;
  runtimeInputs = [
    pi-coding-agent
  ];
}
