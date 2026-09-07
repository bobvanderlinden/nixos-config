{
  writeShellApplication,
  agent,
  coreutils,
  direnv,
  worktree,
}:
writeShellApplication {
  name = "agent-worktree";
  text = builtins.readFile ./agent-worktree.sh;
  runtimeInputs = [
    agent
    coreutils
    direnv
    worktree
  ];
}
