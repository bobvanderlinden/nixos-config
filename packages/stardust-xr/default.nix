{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  cmake,
  meson,
  ninja,
  libX11,
  libGL,
  flatbuffers,
  openxr-loader,
  fontconfig,
  wlroots,
  libstardustxr,
  xdg-utils,
  stereo-kit,
  wayland,
  sk_gpu,
  libxkbcommon,
  udev,
}:

stdenv.mkDerivation rec {
  pname = "stardust-xr";
  version = "0.9.2";

  src = fetchFromGitHub {
    owner = "StardustXR";
    repo = pname;
    rev = version;
    sha256 = "sha256-iXj2YjRp1Kew4MeTg1YOVrCjOhn4FyvhZSRKCPKWZHE=";
    fetchSubmodules = true;
  };

  patches = [ ./shared-libs.patch ];

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    fontconfig
    cmake
  ];

  buildInputs = [
    flatbuffers
    libX11
    libGL
    openxr-loader
    wlroots
    libstardustxr
    xdg-utils
    stereo-kit
    wayland
    sk_gpu
    libxkbcommon
    udev
  ] ++ wlroots.buildInputs;

  NIX_CFLAGS_COMPILE = "-I${sk_gpu.src}/include";

  meta = with lib; {
    homepage = "https://github.com/StardustXR/stardust-xr";
    description = "A Linux XR display server featuring enhanced 2D app support and XR app support";
    maintainers = with maintainers; [ bobvanderlinden ];
    license = licenses.gpl2;
    platforms = platforms.linux;
  };
}
