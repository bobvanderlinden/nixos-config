{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchFromGitLab,
  cmake,
  ninja,
  pkg-config,
  makeWrapper,
  SDL2,
  SDL2_ttf,
  fontconfig,
  gtk3,
  fluidsynth,
  soundfont-fluid,
  zenity,
  gst_all_1,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "3dmmex";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "benstone";
    repo = "3DMMEx";
    rev = "v${finalAttrs.version}";
    hash = "sha256-KhhgJaJJbCjFFnZtMikn8oPPG8ZC7l+Zn2fI6vtK1iA=";
  };

  brenderSrc = fetchFromGitHub {
    owner = "benstone";
    repo = "3DMM-BRender";
    rev = "blazin";
    hash = "sha256-PV9fcYrw+9bmz0B1mZC+9iCX6/sPO4v8ijdHZHl5Sus=";
  };

  miniaudioSrc = fetchFromGitHub {
    owner = "mackron";
    repo = "miniaudio";
    rev = "0.11.23";
    hash = "sha256-ZrfKw5a3AtIER2btCKWhuvygasNaHNf9EURf1Kv96Vc=";
  };

  nativeFileDialogExtendedSrc = fetchFromGitHub {
    owner = "btzy";
    repo = "nativefiledialog-extended";
    rev = "v1.3.0";
    hash = "sha256-JrwJP7zt/4oW4OQHCEM23k+zm6j1AVglGJowwkWc29k=";
  };

  iniparserSrc = fetchFromGitLab {
    domain = "gitlab.com";
    owner = "iniparser";
    repo = "iniparser";
    rev = "main";
    hash = "sha256-z10S9ODLprd7CbL5Ecgh7H4eOwTetYwFXiWBUm6fIr4=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    SDL2
    SDL2_ttf
    fontconfig
    gtk3
    fluidsynth
    zenity
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
  ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_PACKAGES" false)
    (lib.cmakeBool "BUILD_TESTS" false)
    (lib.cmakeFeature "3DMM_GUI" "SDL")
    (lib.cmakeFeature "3DMM_BRENDER_LIBRARY" "Source")
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_3DMM-BRENDER" "${finalAttrs.brenderSrc}")
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_MINIAUDIO" "${finalAttrs.miniaudioSrc}")
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_NATIVEFILEDIALOG-EXTENDED" "${finalAttrs.nativeFileDialogExtendedSrc}")
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_INIPARSER" "${finalAttrs.iniparserSrc}")
  ];

  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail 'execute_process(
  COMMAND git describe --tags --always
  WORKING_DIRECTORY ''${PROJECT_SOURCE_DIR}
  OUTPUT_VARIABLE GIT_VERSION
  OUTPUT_STRIP_TRAILING_WHITESPACE
)' 'if (EXISTS "''${PROJECT_SOURCE_DIR}/.git")
  execute_process(
    COMMAND git describe --tags --always
    WORKING_DIRECTORY ''${PROJECT_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
 else()
  set(GIT_VERSION "v${finalAttrs.version}")
endif()'
  '';

  postInstall = ''
    mkdir -p $out/bin $out/libexec/3dmmex $out/share/3dmmex $out/share/doc/3dmmex

    mv $out/3dmovie $out/libexec/3dmmex/3dmovie
    mv "$out/Microsoft Kids" $out/share/3dmmex/
    mv $out/THIRD_PARTY_LICENSES.txt $out/share/doc/3dmmex/

    ln -s ${soundfont-fluid}/share/soundfonts/FluidR3_GM2-2.sf2 $out/libexec/3dmmex/soundfont.sf3

    makeWrapper $out/libexec/3dmmex/3dmovie $out/bin/3dmmex \
      --chdir $out/share/3dmmex \
      --prefix PATH : ${lib.makeBinPath [ zenity ]}

    ln -s 3dmmex $out/bin/3dmovie
  '';

  meta = {
    description = "Classic 3D Movie Maker port for modern systems";
    homepage = "https://github.com/benstone/3DMMEx";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.bobvanderlinden ];
    mainProgram = "3dmmex";
    platforms = lib.platforms.linux;
  };
})
