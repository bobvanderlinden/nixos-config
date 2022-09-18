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
, openxr-loader
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
    substituteInPlace src/wxrd-renderer.c \
      --replace "#include <types/wlr_buffer.h>" "#include <wlr/types/wlr_buffer.h>"
  '';

  nativeBuildInputs = [
    meson
    ninja
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
    openxr-loader
  ];

  meta = with lib; {
    homepage = "https://gitlab.freedesktop.org/xrdesktop/wxrd";
    description = "A prototype-quality standalone client for xrdesktop based on wlroots and the wxrc codebase";
    maintainers = with maintainers; [ bobvanderlinden ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
