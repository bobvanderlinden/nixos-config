{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  wayland,
  libxkbcommon,
  libglvnd,
  makeWrapper,
}:

rustPlatform.buildRustPackage {
  pname = "wshowkeys-rs";
  version = "1.2.0-unstable-2025-06-20";

  src = fetchFromGitHub {
    owner = "isomoes";
    repo = "wshowkeys_rs";
    rev = "be517db3840b6e346fa6b3b127f973c0badede59";
    hash = "sha256-1Am0UWJWqd+aHXcByTEPTNSyIM+dy8hKVGtZdU4Q97M=";
  };

  cargoHash = "sha256-/HXqrAJrBLuleccIpbliUbMa6UACsc7NTcONpQLWzUk=";

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];
  buildInputs = [
    wayland
    libxkbcommon
    libglvnd
  ];

  postFixup = ''
    wrapProgram $out/bin/wshowkeys_rs \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          wayland
          libxkbcommon
          libglvnd
        ]
      }
  '';

  meta = {
    description = "Keystroke visualizer for Wayland";
    homepage = "https://github.com/isomoes/wshowkeys_rs";
    license = lib.licenses.asl20;
    mainProgram = "wshowkeys_rs";
    platforms = lib.platforms.linux;
  };
}
