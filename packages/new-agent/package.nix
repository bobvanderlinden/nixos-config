{
  writeShellApplication,
  agent-worktree,
  hypr-exec,
}:
writeShellApplication {
  name = "new-agent";
  text = builtins.readFile ./new-agent.sh;
  runtimeInputs = [
    agent-worktree
    hypr-exec
  ];
}
