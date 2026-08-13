{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  git,
  gh,
}:

stdenvNoCC.mkDerivation {
  pname = "gh-batch-merge";
  version = "0.1.0";

  src = ./gh-batch-merge.py;
  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
    python3
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/gh-batch-merge
    patchShebangs $out/bin/gh-batch-merge
    wrapProgram $out/bin/gh-batch-merge \
      --argv0 gh-batch-merge \
      --prefix PATH : ${lib.makeBinPath [ git gh ]}

    runHook postInstall
  '';

  meta = {
    description = "Update and merge approved GitHub PRs one-by-one";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.bobvanderlinden ];
    mainProgram = "gh-batch-merge";
  };
}
