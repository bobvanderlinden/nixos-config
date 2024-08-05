{
  lib,
  stdenv,
  fetchFromGitLab,
  meson,
  ninja,
  pkg-config,
  cmake,
  gxr,
  gulkan,
  gtk3,
  vulkan-loader,
  graphene,
  shaderc,
  python3,
  python3Packages,
  json-glib,
  openxr-loader,
  wrapGAppsHook,
}:

stdenv.mkDerivation rec {
  pname = "xrdesktop";
  version = "0.16.0";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "xrdesktop";
    repo = pname;
    rev = "77ca14f697b6e92f1708504f52f3eb1f654f9d9a";
    hash = "sha256-P/AgIVyAvwGMNIZgPl23DHqRFpHgtPVXsZ8epLY4fiw=";
  };

  nativeBuildInputs = [
    meson
    ninja
    cmake
    pkg-config
    shaderc
    python3Packages.wrapPython
    wrapGAppsHook
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
    python3Packages.pygobject3
    gtk3
  ];

  pythonPath = [ python3Packages.pygobject3 ];

  postFixup = ''
    wrapPythonPrograms
  '';

  meta = with lib; {
    homepage = "https://gitlab.freedesktop.org/xrdesktop/xrdesktop";
    description = "A library for XR interaction with traditional desktop compositors";
    maintainers = with maintainers; [ bobvanderlinden ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
