{ lib
, stdenv
, fetchFromGitHub
, pkg-config
, rustPlatform
, vulkan-loader
, ffmpeg-full
, gtk3
, libunwind
, clang
, alsa-lib
, libjack2
, libXrandr
, openssl
, imagemagick
, vulkan-headers
, llvm
, llvmPackages
}:

rustPlatform.buildRustPackage rec {
  pname = "alvr";
  version = "18.2.3";

  src = fetchFromGitHub {
    owner = "alvr-org";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-H2wtpmCt/gBQkQwpKU+ikWqHkEMhs1+sSPTsVYD0Nos=";
  };

  cargoHash = "sha256-T9dRVCQcD0+8eXbMmKbIIzESTKLtjs/h2RJU8R0g29E=";

  patchPhase = ''
    substituteInPlace alvr/vulkan-layer/layer/alvr_x86_64.json \
      --replace "../../../lib64/libalvr_vulkan_layer.so" "libalvr_vulkan_layer.so"
  '';

  nativeBuildInputs = [
    pkg-config
    imagemagick
    rustPlatform.bindgenHook
    vulkan-headers
  ];

  buildInputs = [
    vulkan-loader
    (ffmpeg-full.override {
      # From shell.nix
      nonfreeLicensing = true;
      samba = null;
    })
    gtk3
    alsa-lib
    libjack2
    libXrandr
    openssl
    libunwind
  ];

  cargoBuildFlags = [
    "--package alvr_server"
    "--package alvr_launcher"
    "--package alvr_vulkan-layer"
    "--package vrcompositor-wrapper"
  ];

  NIX_CFLAGS_COMPILE = [ "-I${vulkan-headers}/include" ];
  NIX_LDFLAGS = [
    "-L${vulkan-loader}/lib"
    "-lvulkan"
    "-L${ffmpeg-full}/lib"
    "-lavutil"
  ];

  ALVR_ROOT_DIR = placeholder "out";
  ALVR_LIBRARIES_DIR = "${ALVR_ROOT_DIR}/lib";
  ALVR_OPENVR_DRIVER_ROOT_DIR = "${ALVR_LIBRARIES_DIR}/steamvr/alvr/";
  ALVR_VRCOMPOSITOR_WRAPPER_DIR = "${ALVR_LIBRARIES_DIR}";

  postInstall = ''
    install -Dm644 LICENSE -t "$out/share/licenses/$${pname}/"

    # OpenVR Driver
    install -d "$out/lib/steamvr/alvr/bin/linux64"
    ln -s $out/lib/libalvr_server.so "$out/lib/steamvr/alvr/bin/linux64/driver_alvr_server.so"
    install -Dm644 alvr/xtask/resources/driver.vrdrivermanifest -t "$out/lib/steamvr/alvr/"

    # Vulkan Layer
    install -Dm644 alvr/vulkan-layer/layer/alvr_x86_64.json -t "$out/share/vulkan/explicit_layer.d/"


    install -d $out/share/alvr/{dashboard,presets}
    install -Dm644 alvr/xtask/resources/presets/* -t "$out/share/alvr/presets/"
    cp -ar alvr/dashboard $out/share/alvr/

    install -Dm644 packaging/freedesktop/alvr.desktop -t "$out/share/applications"
  '';

  doCheck = false;

  meta = with lib; {
    homepage = "https://github.com/alvr-org/ALVR";
    description = ''
      Stream VR games from your PC to your headset via Wi-Fi
    '';
    maintainers = with maintainers; [ bobvanderlinden ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
