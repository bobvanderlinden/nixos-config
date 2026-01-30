{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  pipewire,
  alsa-lib,
  openssl,
  llvmPackages,
  cmake,
  git,
}:

rustPlatform.buildRustPackage rec {
  pname = "waystt";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "sevos";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-7RKYqED2/aPDvofNGAa48DTexQYdUqkQzb7BX0CsDCU=";
  };

  cargoHash = "sha256-W2pfYDPFyo/ICZ5Y0nLsP4ZeUe7lBffItelnWXrOSLc=";

  nativeBuildInputs = [
    pkg-config
    cmake
    git
  ];

  LIBCLANG_PATH = "${lib.getLib llvmPackages.libclang}/lib";

  buildInputs = [
    pipewire
    alsa-lib
    openssl
  ];

  meta = with lib; {
    description = "Speech-to-text tool for Wayland with stdout output";
    homepage = "https://github.com/sevos/waystt";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    mainProgram = "waystt";
    platforms = platforms.linux;
  };
}
