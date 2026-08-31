{
  hyprlandPlugins,
  lib,
  lua5_4,
  src,
}:
let
  version = "unstable-2026-08-08";
in
hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "scrolloverview";
  inherit src version;

  buildInputs = [ lua5_4 ];
  dontUseCmakeConfigure = true;
  enableParallelBuilding = true;

  buildPhase = ''
    runHook preBuild
    export SCROLLOVERVIEW_BUILD_VERSION="${version}"
    make all
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install --directory "$out/lib"
    install --mode=755 scrolloverview.so "$out/lib/libscrolloverview.so"
    runHook postInstall
  '';

  meta = {
    description = "Scrollable workspace overview plugin for Hyprland";
    homepage = "https://github.com/yayuuu/hyprland-scroll-overview";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
