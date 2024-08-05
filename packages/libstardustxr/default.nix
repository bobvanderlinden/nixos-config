{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  meson,
  ninja,
  flatbuffers,
  libxkbcommon,
}:

stdenv.mkDerivation rec {
  pname = "libstardustxr";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "StardustXR";
    repo = pname;
    # Tag 0.9.0 is versioned 0.1.0 in Meson.
    rev = "5f32662e4b4b86c87be106ef0a0213281ceba88c";
    sha256 = "sha256-CSW01J0P70S6MOAl11Gx5tPZ2zrySZzBl1X7bM0PpDU=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [
    flatbuffers
    libxkbcommon
  ];

  mesonFlags = [
    "-Dclient=true"
    "-Dserver=true"
    "-Dfusion=true"
  ];

  meta = with lib; {
    homepage = "https://";
    description = "";
    maintainers = with maintainers; [ bobvanderlinden ];

    # license = licenses.mit;
    # license = licenses.gpl3;
    # license = licenses.free;
    # license = licenses.gpl2;
    # license = licenses.gpl2Plus;
    # license = licenses.gpl3Plus;
    # license = licenses.asl20;
    # license = licenses.bsd3;

    # platforms = platforms.linux;
    # platforms = platforms.unix;
    # platforms = platforms.all;
  };
}
