{ lib
, stdenv
, fetchFromGitLab
, fetchpatch
, meson
, ninja
, pkg-config
, cmake
, gtk3
, vulkan-loader
, graphene
, cairo
, shaderc
}:

stdenv.mkDerivation rec {
  pname = "gulkan";
  version = "0.15.2";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "xrdesktop";
    repo = pname;
    rev = version;
    hash = "sha256-Kb0Vt19dhkvT6XlxCKcaEBnZb7/fMmRL55+A2mRdn80=";
  };

  patches = [
    (fetchpatch {
      url = "https://gitlab.freedesktop.org/xrdesktop/gulkan/-/commit/ea94e97a58538090f65fae3b94395e5c08d4b8ee.patch";
      hash = "sha256-CERzQQx0LhEJgudkafsUXQn7y73/wfwKSJg/Y4ASlH4=";
    })
  ];

  nativeBuildInputs = [
    meson
    ninja
    cmake
    pkg-config
    shaderc
  ];

  buildInputs = [
    gtk3
    vulkan-loader
    graphene
    cairo
  ];

  meta = with lib; {
    homepage = "https://gitlab.freedesktop.org/xrdesktop/gulkan";
    description = "A GLib library for Vulkan abstraction. It provides classes for handling Vulkan instances, devices, shaders and initialize textures GDK Pixbufs, Cairo surfaces and DMA buffers";
    maintainers = with maintainers; [ bobvanderlinden ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
