{ lib
, stdenv
, fetchFromSourcehut
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
, cglm
, cairo
, mesa
, openxr-loader
, vulkan-headers
, pango
, wayland
, wayland-protocols

}:

let
  wlroots-0_16 = wlroots.overrideAttrs
    (oldAttrs: rec {
      version = "0.16-42ae1e75";
      src = fetchFromGitLab
        {
          domain = "gitlab.freedesktop.org";
          owner = "wlroots";
          repo = "wlroots";
          rev = "42ae1e75aa22c9f8063300dcca846b35c03022e5";
          sha256 = "sha256-InyL6mZiXbj9UxE+0h+bqyKtXtcl9Ar+5uu2ufMAMaI=";
        };
    });

  cglm-fix = cglm.overrideAttrs (oldAttrs: rec {
    cmakeFlags = [
      "-DCMAKE_INSTALL_INCLUDEDIR=include"
      "-DCMAKE_INSTALL_LIBDIR=lib"
    ];
  });
in
stdenv.mkDerivation rec {
  pname = "wxrc";
  version = "0.0.1-fdde9281";

  src = fetchFromSourcehut {
    owner = "~bl4ckb0ne";
    repo = pname;
    rev = "fdde9281b0d25a26e373dea20eee0510765cf8ef";
    hash = "sha256-4lDmGOHrJ6o10tViky4ATBJEMc+OSPIVBAYYEKBhCxE=";
  };

  patchPhase = ''
    for file in common/dmabuf-buffer.c common/composite-buffer.c wxrbg/main.c wxrbg/wayland.c wxrc/display.h wxrc/seat.c wxrhud/wayland.c
    do
      substituteInPlace "$file" \
        --replace "drm_fourcc.h" "libdrm/drm_fourcc.h"
    done
  '';

  nativeBuildInputs = [
    meson
    ninja
    cmake
    pkg-config
  ];

  buildInputs = [
    libxkbcommon
    wlroots-0_16
    cglm-fix
    cairo
    mesa
    openxr-loader
    vulkan-headers
    vulkan-loader
    pango
    wayland
    wayland-protocols
    udev
    libdrm
  ];

  NIX_CFLAGS_COMPILE = [ "-fno-strict-aliasing" ];
  NIX_LDFLAGS = "-ldl -lm -lpthread -lwayland-server -lxkbcommon -lwayland-client";

  meta = with lib; {
    homepage = "https://git.sr.ht/~bl4ckb0ne/wxrc";
    description = "A Wayland OpenXR compositor based on wlroots";
    maintainers = with maintainers; [ bobvanderlinden ];
    license = licenses.free;
    platforms = platforms.linux;
  };
}

