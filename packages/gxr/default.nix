{ lib
, stdenv
, fetchFromGitLab
, meson
, ninja
, pkg-config
, cmake
, gulkan
, glib
, vulkan-loader
, cairo
, graphene
, gdk-pixbuf
, gtk3
, json-glib
, shaderc
}:

stdenv.mkDerivation rec {
  pname = "gxr";
  version = "0.15.2";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "xrdesktop";
    repo = pname;
    rev = version;
    hash = "sha256-Fu52sLxIjc07tifBbtYu4LT7c1wZhC4cmEDH1WeyT7o=";
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
  ];

  meta = with lib; {
    homepage = "https://gitlab.freedesktop.org/xrdesktop/gxr";
    description = "A GLib XR library utilizing the OpenXR and OpenVR APIs";
    maintainers = with maintainers; [ bobvanderlinden ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
