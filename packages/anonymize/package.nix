{
  writeShellApplication,
  python3,
}:
writeShellApplication {
  name = "anonymize";
  runtimeInputs = [ python3 ];
  text = ''
    exec python3 "${./anonymize.py}" "$@"
  '';

  checkPhase = ''
    runHook preCheck
    ANONYMIZE_SCRIPT=${./anonymize.py} ${python3}/bin/python3 ${./test_anonymize.py}
    runHook postCheck
  '';
}
