{
  writeShellApplication,
  agent,
  hypr-exec,
  worktree,
}:
writeShellApplication {
  name = "new-agent";
  text = builtins.readFile ./new-agent.sh;
  runtimeInputs = [
    agent
    hypr-exec
    worktree
  ];
}
