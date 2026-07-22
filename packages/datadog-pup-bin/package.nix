{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "1.6.6";
  releases = {
    aarch64-darwin = {
      platform = "Darwin_arm64";
      hash = "sha256-RJgKYA6xuEq8Y83LPVPR/ZXSMmC2oQbu3iA4b1l1wj0=";
    };
    aarch64-linux = {
      platform = "Linux_arm64";
      hash = "sha256-NY4ioyYzOIKTsAiUawHAv7D20dPCdBjfkyJFrnhbuvk=";
    };
    x86_64-darwin = {
      platform = "Darwin_x86_64";
      hash = "sha256-WfIFL1djgprSBVVpj4YHB4h3yJxfG6FprqzZ7xFMBZs=";
    };
    x86_64-linux = {
      platform = "Linux_x86_64";
      hash = "sha256-pNYT4pCT4xzh/4DKyCnmkIcOLeGusKO/Omyh4/9Ecus=";
    };
  };
  release = releases.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "datadog-pup-bin";
  inherit version;

  src = fetchurl {
    url = "https://github.com/DataDog/pup/releases/download/v${version}/pup_${version}_${release.platform}.tar.gz";
    inherit (release) hash;
  };
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 pup "$out/bin/pup"

    runHook postInstall
  '';

  meta = {
    description = "AI-agent-ready command-line interface for Datadog's observability platform";
    homepage = "https://github.com/DataDog/pup";
    license = lib.licenses.asl20;
    maintainers = [ ];
    mainProgram = "pup";
    platforms = builtins.attrNames releases;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
