{ lib
, stdenv
, fetchFromGitLab
, meson
, ninja
, pkg-config
, cmake
, gxr
, gulkan
, gtk3
, vulkan-loader
, graphene
, shaderc
, python3
, python3Packages
, json-glib
, openxr-loader
}:

stdenv.mkDerivation rec {
  pname = "xrdesktop";
  version = "0.16.0";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "xrdesktop";
    repo = pname;
    rev = "2fd523947e7e0114165e71c1469350b5d04135fd";
    hash = "sha256-YcJQVoCbtwlWBTihIFJWK5IhY/b++TCOmpNaWUrQBdU=";
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
    gxr
    gulkan
    python3
    json-glib
    openxr-loader
  ];

  propagatedBuildInputs = [
    python3Packages.pygobject3
    gtk3
  ];

  meta = with lib; {
    homepage = "https://gitlab.freedesktop.org/xrdesktop/xrdesktop";
    description = "A library for XR interaction with traditional desktop compositors";
    maintainers = with maintainers; [ bobvanderlinden ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
