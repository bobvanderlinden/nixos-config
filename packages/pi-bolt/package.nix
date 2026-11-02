{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libxcb,
  makeWrapper,
  fd,
  ripgrep,
}:
let
  version = "1.0.7";
  releases = {
    x86_64-linux = {
      platform = "linux-x64-baseline";
      hash = "sha256:604f2d19594ae45d307885c0b74769159737e63c85d535f78608e3bf1320746f";
    };
    aarch64-linux = {
      platform = "linux-arm64";
      hash = "sha256:5aa2e0770ad7bc7618c14ce1f02c995f14f0982d390f7f35a4ec528278643fd8";
    };
  };
  release = releases.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "pi-bolt";
  inherit version;

  src = fetchurl {
    url = "https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v${version}/pi-bolt-${release.platform}.tar.xz";
    inherit (release) hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [ libxcb ];

  # Pi-Bolt reads embedded data at fixed ELF offsets. Preserve those sections
  # when changing the interpreter, and skip the standard binary fixups.
  dontStrip = true;
  dontPatchELF = true;
  patchelfFlags = [ "--no-clobber-old-sections" ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/pi" --help > help.txt
    grep -q 'AI coding assistant' help.txt
    "$out/bin/pi" --version | grep -F 'Pi-Bolt ${version}'
    runHook postInstallCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/pi-bolt" "$out/bin"
    cp -a . "$out/lib/pi-bolt/"
    makeWrapper "$out/lib/pi-bolt/pi" "$out/bin/pi" \
      --prefix PATH : ${lib.makeBinPath [ fd ripgrep ]} \
      --set PI_PACKAGE_DIR "$out/lib/pi-bolt" \
      --set PI_SKIP_VERSION_CHECK 1 \
      --set PI_TELEMETRY 0
    ln -s pi "$out/bin/pi-bolt"

    runHook postInstall
  '';

  meta = {
    description = "Pi coding agent compiled ahead of time to native code";
    homepage = "https://github.com/opensec-git/Pi-Bolt";
    license = lib.licenses.mit;
    mainProgram = "pi-bolt";
    platforms = builtins.attrNames releases;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
