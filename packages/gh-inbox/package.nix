{
  writeShellApplication,
  gh,
  python3,
}:
writeShellApplication {
  name = "gh-inbox";
  runtimeInputs = [
    gh
    python3
  ];
  text = ''
    exec python3 "${./gh-inbox.py}" "$@"
  '';
}
