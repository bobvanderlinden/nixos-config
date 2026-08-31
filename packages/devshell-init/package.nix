{
  writeShellApplication,
  python3,
  direnv,
  git,
}:
writeShellApplication {
  name = "devshell-init";
  runtimeInputs = [
    python3
    direnv
    git
  ];
  text = ''
    exec python3 "${./devshell-init.py}" "$@"
  '';
}
