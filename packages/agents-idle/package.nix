{
  writeShellApplication,
  python3,
}:
writeShellApplication {
  name = "agents-idle";
  runtimeInputs = [ python3 ];
  text = ''
    exec python3 "${./agents-idle.py}" "$@"
  '';
}
