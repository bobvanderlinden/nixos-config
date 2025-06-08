{
  lib,
  stdenv,
  fetchFromGitLab,
  fetchpatch,
  meson,
  ninja,
  pkg-config,
  cmake,
  gtk3,
  vulkan-loader,
  graphene,
  cairo,
  shaderc,
  libdrm,
}:

stdenv.mkDerivation rec {
  pname = "gulkan";
  version = "0.16.0";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "xrdesktop";
    repo = pname;
    rev = "f7376559cf9dc92dc83f6e5d2472c71091197a29";
    hash = "sha256-2VAhPm4K3RNH5l3uV1QQUXauMJxwEbahX5iKUfUR4uE=";
  };

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
    libdrm
  ];

  meta = with lib; {
    homepage = "https://gitlab.freedesktop.org/xrdesktop/gulkan";
    description = "A GLib library for Vulkan abstraction. It provides classes for handling Vulkan instances, devices, shaders and initialize textures GDK Pixbufs, Cairo surfaces and DMA buffers";
    maintainers = with maintainers; [ bobvanderlinden ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
