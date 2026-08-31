{
  lib,
  buildGoModule,
  fetchFromGitHub,
  gtk4,
  gobject-introspection,
  pkg-config,
  zig,
}:

buildGoModule rec {
  pname = "tapshow";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "hmnd";
    repo = "tapshow";
    rev = "v${version}";
    hash = "sha256-QzN2OVgcmC7m63BwY+B/hnkW5YtZjNmrdeo25Qryq94=";
  };

  vendorHash = "sha256-UF3Qsu1BywJrKSNrZUbxChsS0qjbMo2nlOK5zcLiirY=";

  nativeBuildInputs = [
    pkg-config
    zig
  ];
  buildInputs = [
    gtk4
    gobject-introspection
  ];

  CC = "${zig}/bin/zig cc";
  CXX = "${zig}/bin/zig c++";

  ldflags = [ "-X main.version=${version}" ];

  meta = {
    description = "Keystroke visualizer for Wayland";
    homepage = "https://github.com/hmnd/tapshow";
    license = lib.licenses.mit;
    mainProgram = "tapshow";
    platforms = lib.platforms.linux;
  };
}
