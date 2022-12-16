{ lib
, stdenv
, fetchurl
, fetchFromGitHub
, pkg-config
, cmake
, python3
, spirv-tools
, spirv-cross
, spirv-headers
, glslang
, libX11
, glew
}:
let
  cpm = fetchurl {
    url = "https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.32.2/CPM.cmake";
    hash = "sha256-yDHlpqmpAE8CWiwJRoWyaqbuBAg0090G8WJIC2KLHp8=";
  };

  # SPIRV-Cross = fetchFromGitHub {
  #   owner = "KhronosGroup";
  #   rev = "50b4d5389b6a06f86fb63a2848e1a7da6d9755ca";
  #  };

  spirv-cross-fix = spirv-cross.overrideAttrs (oldAttrs: {
    cmakeFlags = [
      "-DSPIRV_CROSS_SHARED=ON"
      "-DCMAKE_INSTALL_LIBDIR=lib"
      "-DCMAKE_INSTALL_INCLUDEDIR=include"
    ];
  });
in
stdenv.mkDerivation rec {
  pname = "sk_gpu";
  version = "1.2";

  src = fetchFromGitHub {
    owner = "StereoKit";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-7flJfl4CwTN9ZhcBqvkc/nOirdLuFzoTC0rT39/xcDQ=";
  };

  patchPhase = ''
    mkdir -p build/cmake
    cp -R --no-preserve=mode,ownership ${cpm} build/cmake/CPM_0.32.2.cmake
    
    mkdir -p /build/source/build/skshaderc
    cp -R --no-preserve=mode,ownership ${spirv-cross.src}/ /build/source/build/skshaderc/spirv-cross
    cp -R --no-preserve=mode,ownership ${spirv-headers.src}/ /build/source/build/skshaderc/spirv-headers
    cp -R --no-preserve=mode,ownership ${spirv-tools.src}/ /build/source/build/skshaderc/spirv-tools
    cp -R --no-preserve=mode,ownership ${glslang.src}/ /build/source/build/skshaderc/glslang

    substituteInPlace src/CMakeLists.txt \
      --replace "}../sk_gpu.h" "}/../sk_gpu.h"
  '';

  nativeBuildInputs = [
    pkg-config
    cmake
    python3
  ];

  buildInputs = [
    libX11
    glew
    spirv-cross-fix
    spirv-headers
    spirv-tools
    glslang
  ];

  cmakeFlags = [
    "-DCPM_USE_LOCAL_PACKAGES=ON"
    "-DCPM_LOCAL_PACKAGES_ONLY=ON"
  ];

  meta = with lib; {
    homepage = "https://github.com/StereoKit/sk_gpu";
    description = "Cross-platform single header graphics library for StereoKit, in progress. Works with OpenXR on Desktop, HoloLens, and Quest";
    maintainers = with maintainers; [ bobvanderlinden ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
