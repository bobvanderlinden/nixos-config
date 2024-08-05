{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  pkg-config,
  cmake,
  libGL,
  libX11,
  fontconfig,
  reactphysics3d,
  openxr-loader,
  glew,
  makePkgconfigItem,
  copyPkgconfigItems,
}:
let
  cpm = fetchurl {
    url = "https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.32.2/CPM.cmake";
    hash = "sha256-yDHlpqmpAE8CWiwJRoWyaqbuBAg0090G8WJIC2KLHp8=";
  };
in
# reactphysics3d = fetchFromGitHub {
#   owner = "DanielChappuis";
#   repo = "reactphysics3d";
#   rev = "17dd22e677ed861b0d4ece0c00a7e3cb503cc2f0";
#   hash = "sha256-aPbQw0vHjh9ltPdrEo6t1+o89ABAjvi8zlAdZ0S7IYI=";
# };
# openxr = fetchFromGitHub {
#   owner = "KhronosGroup";
#   repo = "OpenXR-SDK";
#   rev = "release-1.0.24";
#   hash = "sha256-Bd8mdQgv031sCMEb7QGDBNRyLSO6VwfsYtjyCwfga9I=";
# };
stdenv.mkDerivation rec {
  pname = "StereoKit";
  version = "0.3.6";

  src = fetchFromGitHub {
    owner = pname;
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-Nf38QxAPAIpxw8WwPoe01YJHlcOH6rS0TuRbnCA4bHA=";
  };

  patchPhase = ''
    mkdir -p build/cmake
    cp ${cpm} build/cmake/CPM_0.32.2.cmake
    substituteInPlace CMakeLists.txt \
      --replace CPMAddPackage CPMFindPackage \
      --replace "NAME reactphysics3d" "NAME reactphysics3d VERSION 0.9.0" \
      --replace "reactphysics3d" "ReactPhysics3D" \
      --replace "# find_package(PkgConfig)" "find_package(PkgConfig)"
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
    copyPkgconfigItems
  ];

  buildInputs = [
    libGL
    libX11
    fontconfig
    reactphysics3d
    openxr-loader
    glew
  ];

  cmakeFlags = [
    # "-DCMAKE_FIND_DEBUG_MODE=TRUE"
    "-DSK_PHYSICS=off"
  ];

  CPM_LOCAL_PACKAGES_ONLY = true;

  pkgconfigItems = [
    (makePkgconfigItem rec {
      name = "StereoKitC";
      inherit version;
      cflags = [ "-I${variables.includedir}" ];
      libs = [
        "-L${variables.libdir}"
        "-Wl,--rpath ${variables.libdir}"
        "-lStereoKitC"
      ];
      variables = rec {
        prefix = "${placeholder "out"}";
        includedir = "${prefix}/include";
        libdir = "${prefix}/lib";
      };
      description = "Open source C++ physics engine library in 3D";
    })
  ];

  meta = with lib; {
    homepage = "https://github.com/StereoKit/StereoKit";
    description = "An easy-to-use mixed reality library for building HoloLens and VR applications with C# and OpenXR";
    maintainers = with maintainers; [ bobvanderlinden ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
