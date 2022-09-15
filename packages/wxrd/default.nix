{ lib
, stdenv
, fetchFromGitLab
, meson
, ninja
, pkg-config
, cmake
, xrdesktop
, gxr
, libxkbcommon
, libdrm
, wlroots
, gulkan
, vulkan-loader
, graphene
, udev
}:

stdenv.mkDerivation rec {
  pname = "wxrd";
  version = "0.0.1-01669afc";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "xrdesktop";
    repo = pname;
    rev = "01669afc98fdc3629b9025eb18f0f9c29516d045";
    hash = "sha256-fEP5ZpkJtWN7friKYPvyUOhpgmzTtdLDr/O+hlQCb6Q=";
  };

  patchPhase = ''
    substituteInPlace meson.build \
      --replace "xrdesktop_version = ['>=0.16.0']," "xrdesktop_version = ['>=0.15.0']" \
      --replace "xrdesktop-0.16" "xrdesktop-0.15"
    substituteInPlace src/view.c \
      --replace xrd_{shell,client}_add_window \
      --replace xrd_{shell,client}_remove_window
  '';

  nativeBuildInputs = [
    meson
    ninja
    cmake
    pkg-config
  ];

  buildInputs = [
    xrdesktop
    libxkbcommon
    libdrm
    wlroots
    gxr
    gulkan
    vulkan-loader
    graphene
    udev
  ];

  meta = with lib; {
    homepage = "https://gitlab.freedesktop.org/xrdesktop/wxrd";
    description = "A prototype-quality standalone client for xrdesktop based on wlroots and the wxrc codebase";
    maintainers = with maintainers; [ bobvanderlinden ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
