{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  cmake,
  libX11,
  glew,
  libGL,
  libXdamage,
}:

stdenv.mkDerivation rec {
  pname = "x3d";
  version = "0.0.0";

  src = fetchFromGitHub {
    owner = "Codes4Fun";
    repo = pname;
    rev = "39d6e5f65a6042598085ae61dc208a1f9965f0d1";
    sha256 = "sha256-O2zfMsWbEeTeZazYXzBTFL7FF8rgO5RJBLTLsmtf8Xs=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    libX11
    glew
    libGL
    libXdamage
  ];

  meta = with lib; {
    homepage = "https://github.com/Codes4Fun/x3d";
    description = "Exploration of a VR desktop 2012, updated with OpenVR";
    maintainers = with maintainers; [ bobvanderlinden ];
    # license = licenses.unknown?;
    platforms = platforms.linux;
  };
}
