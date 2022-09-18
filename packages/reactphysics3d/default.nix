{ lib
, stdenv
, fetchFromGitHub
, pkg-config
, cmake
, ninja
, makePkgconfigItem
, copyPkgconfigItems
}:

stdenv.mkDerivation rec {
  pname = "reactphysics3d";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "DanielChappuis";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-AUdsUXsygsGfS8H+AHEV1fSrrX7zGmfsaTONYUG3zqk=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    copyPkgconfigItems
  ];

  cmakeFlags = [ "-DBUILD_SHARED_LIBS=ON" ];

  pkgconfigItems = [
    (makePkgconfigItem rec {
      name = "reactphysics3d";
      inherit version;
      cflags = [ "-I${variables.includedir}" ];
      libs = [
        "-L${variables.libdir}"
        "-Wl,--rpath ${variables.libdir}"
        "-lreactphysics3d"
      ];
      variables = rec {
        prefix = "${placeholder "out"}";
        includedir = "${prefix}/include/reactphysics3d";
        libdir = "${prefix}/lib";
      };
      description = "Open source C++ physics engine library in 3D";
    })
  ];

  meta = with lib; {
    homepage = "https://www.reactphysics3d.com/";
    description = "Open source C++ physics engine library in 3D";
    maintainers = with maintainers; [ bobvanderlinden ];
    license = licenses.zlib;
    platforms = platforms.linux;
  };
}
