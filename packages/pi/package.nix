{
  lib,
  buildNpmPackage,
  bun,
  fetchFromGitHub,
  fetchzip,
  fd,
  makeWrapper,
  ripgrep,
}:
buildNpmPackage rec {
  pname = "pi";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    rev = "abe508e1b89912adde45528136c3221eb69acdd7";
    hash = "sha256-lwjspkMGrW+8Fl/yBEDEFsHZJA57OKOhmVQmi6zfej4=";
  };

  npmDepsHash = "sha256-GOh5WG+rRgzoy/yVHY5PoEKJZGQcEGhISrDDJxkP8W4=";

  modelData = fetchzip {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
    hash = "sha256-G1JV7jbZfVPcbCVb7lnj+8vqrnntsG0w7RZEzOvnKO4=";
  };
  npmInstallFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [ "--ignore-scripts" ];

  doCheck = false;
  doInstallCheck = false;


  nativeBuildInputs = [
    bun
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    cp --recursive ${modelData}/dist/providers/data packages/ai/src/providers/
    npm run build:offline
    bun build --compile --no-compile-autoload-bunfig --no-compile-autoload-dotenv \
      ./packages/coding-agent/dist/bun/cli.js \
      ./packages/coding-agent/src/utils/image-resize-worker.ts \
      ./packages/coding-agent/src/extensions/codemode/worker.ts \
      --outfile packages/coding-agent/dist/pi
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    packageDirectory=$out/libexec/pi
    mkdir --parents "$packageDirectory/theme" "$packageDirectory/assets"
    cp packages/coding-agent/dist/pi "$packageDirectory/"
    cp packages/coding-agent/{package.json,README.md,CHANGELOG.md} "$packageDirectory/"
    cp node_modules/@silvia-odwyer/photon-node/photon_rs_bg.wasm "$packageDirectory/"
    cp packages/coding-agent/src/modes/interactive/theme/*.json "$packageDirectory/theme/"
    cp packages/coding-agent/src/modes/interactive/assets/* "$packageDirectory/assets/"
    cp --recursive packages/coding-agent/dist/core/export-html "$packageDirectory/"
    cp --recursive packages/coding-agent/{docs,examples} "$packageDirectory/"

    makeWrapper "$packageDirectory/pi" "$out/bin/pi" \
      --prefix PATH : ${
        lib.makeBinPath [
          fd
          ripgrep
        ]
      } \
      --set PI_PACKAGE_DIR "$packageDirectory" \
      --set PI_SKIP_VERSION_CHECK 1 \
      --set PI_TELEMETRY 0

    runHook postInstall
  '';

  meta = {
    description = "A terminal-based coding agent with multi-model support";
    homepage = "https://github.com/earendil-works/pi";
    license = lib.licenses.mit;
    mainProgram = "pi";
    platforms = lib.platforms.linux;
  };
}
