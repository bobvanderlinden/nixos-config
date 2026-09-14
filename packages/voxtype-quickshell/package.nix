{
  stdenvNoCC,
  voxtype,
}:

stdenvNoCC.mkDerivation {
  pname = "voxtype-quickshell";
  inherit (voxtype) version src;

  installPhase = ''
    runHook preInstall

    install --directory "$out/share/voxtype"
    cp --recursive quickshell "$out/share/voxtype/quickshell"

    runHook postInstall
  '';
}
