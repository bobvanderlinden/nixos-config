{
  lib,
  stdenv,
  fetchFromGitLab,
  pkg-config,
  meson,
  ninja,
  cmake,
  gtk2,
  glib,
  libX11,
  libXtst,
  libXi,
  mutter,
  json-glib,
  xdotool,
}:

stdenv.mkDerivation rec {
  pname = "libinputsynth";
  version = "0.16.0";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "xrdesktop";
    repo = pname;
    rev = "f369bcf1301aa8b6cac82d1656112e7a3bee2fd4";
    hash = "sha256-OqLv+k2aXBGRoRfaDZoWv66WJ5TasuezygAwQ94z4OQ=";
  };

  patchPhase = ''
    substituteInPlace meson.build \
      --replace /usr/lib ${xdotool}/lib
  '';

  nativeBuildInputs = [
    pkg-config
    meson
    ninja
    cmake
  ];

  buildInputs = [
    gtk2
    glib
    libX11
    libXtst
    libXi
    mutter
    json-glib
    xdotool
  ];

  meta = with lib; {
    homepage = "https://gitlab.freedesktop.org/xrdesktop/libinputsynth";
    description = "Synthesize keyboard and mouse input on X11 and Wayland with various backends";
    maintainers = with maintainers; [ bobvanderlinden ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
