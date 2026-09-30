{
  autoPatchelfHook,
  fetchurl,
  lib,
  makeWrapper,
  python3,
  stdenv,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "colibri";
  version = "1.11.0";

  src = fetchurl {
    url = "https://github.com/JustVugg/colibri/releases/download/v${finalAttrs.version}/colibri-v${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-AbyoCTCfBkfTKZjH1vC/n6L2X+DDlbLHL0cB29Wzda0=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [ stdenv.cc.cc.lib ];

  dontConfigure = true;
  dontBuild = true;
  unpackPhase = ''
    tar --extract --gzip --file "$src"
  '';

  installPhase = ''
    runHook preInstall

    install --directory "$out/bin" "$out/libexec/colibri"
    cp --recursive . "$out/libexec/colibri/"
    patchShebangs "$out/libexec/colibri"

    makeWrapper "$out/libexec/colibri/coli" "$out/bin/coli" \
      --prefix PATH : ${lib.makeBinPath [ python3 ]}

    runHook postInstall
  '';

  meta = {
    description = "Local inference engine for large mixture-of-experts models";
    homepage = "https://github.com/JustVugg/colibri";
    license = lib.licenses.mit;
    mainProgram = "coli";
    platforms = [ "x86_64-linux" ];
  };
})
