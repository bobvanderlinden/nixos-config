{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  pi,
}:
stdenvNoCC.mkDerivation rec {
  pname = "pi-web";
  version = "0.0.1-beta.38";

  src = fetchurl {
    url = "https://github.com/ygncode/pi-web/releases/download/v${version}/pi-web-linux-amd64";
    hash = "sha256-ZuP63b66bJqFmgRgR4JUN734tB2AJpXc72FF3R4Fhhg=";
  };

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/pi-web"
    wrapProgram "$out/bin/pi-web" --prefix PATH : ${lib.makeBinPath [ pi ]}
    runHook postInstall
  '';

  meta = {
    description = "Browser interface for Pi coding agent sessions";
    homepage = "https://github.com/ygncode/pi-web";
    license = lib.licenses.mit;
    mainProgram = "pi-web";
    platforms = [ "x86_64-linux" ];
  };
}
