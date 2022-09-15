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
}:

stdenv.mkDerivation rec {
  pname = "xrdesktop";
  version = "0.15.2";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "xrdesktop";
    repo = pname;
    rev = version;
    hash = "sha256-3qdJHnjTsa53t0V1cRUeBVb4wONRI4eOvxRJS75jWSg=";
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
