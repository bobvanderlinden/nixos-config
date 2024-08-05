{
  lib,
  stdenv,
  fetchFromGitLab,
  meson,
  ninja,
  pkg-config,
  cmake,
  gulkan,
  glib,
  vulkan-loader,
  cairo,
  graphene,
  gdk-pixbuf,
  gtk3,
  json-glib,
  shaderc,
  openxr-loader,
  wlroots,
}:
stdenv.mkDerivation rec {
  pname = "gxr";
  version = "0.16.0";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "xrdesktop";
    repo = pname;
    rev = "ff20019d60697d396f182c8e0ef1dc189480a8da";
    hash = "sha256-LiOGlV81C2Yp/U6NfLXiYnjcZbC27Xua7I4SJz4PTtc=";
  };

  nativeBuildInputs = [
    meson
    ninja
    cmake
    pkg-config
    gdk-pixbuf
  ];

  buildInputs = [
    gulkan
    glib
    gtk3
    vulkan-loader
    cairo
    graphene
    json-glib
    shaderc
    openxr-loader
    wlroots
  ];

  meta = with lib; {
    homepage = "https://gitlab.freedesktop.org/xrdesktop/gxr";
    description = "A GLib XR library utilizing the OpenXR and OpenVR APIs";
    maintainers = with maintainers; [ bobvanderlinden ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
