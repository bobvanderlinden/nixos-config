{
  lib,
  buildNpmPackage,
  bun,
  fetchFromGitHub,
  fetchpatch,
  fetchzip,
  fd,
  makeWrapper,
  ripgrep,
  stdenv,
}:
buildNpmPackage rec {
  pname = "pi";
  version = "0.84.4";

  src = fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    rev = "853a80d26c90a14c1886f0ebb8ffaae133ca2185";
    hash = "sha256-y6+6KYpTRLldUV/fSAOsDpQK310ofZ3b0b9vHFZ0MSE=";
  };

  npmDepsHash = "sha256-35GC3Q4Jf4URvqoEYHeM63x49tTmrth62//PvKm4I7Q=";

  modelData = fetchzip {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
    hash = "sha256-5RUH1YbGFRRrPsljziBfmdRBX97XpBl9S4I1AehLaYM=";
  };
  npmInstallFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [ "--ignore-scripts" ];

  doCheck = false;
  doInstallCheck = false;

  patches = [
    (fetchpatch {
      url = "https://github.com/earendil-works/pi/pull/8787.patch";
      hash = "sha256-9DciubHPLL5UyE+BXOeSwFjRS9UfU0FhS2rxS75tbRY=";
    })
  ];

  nativeBuildInputs = [
    bun
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    npm --prefix packages/tui run build
    npm --prefix packages/telemetry run build
    cp --recursive ${modelData}/dist/providers/data packages/ai/src/providers/
    (cd packages/ai && ../../node_modules/.bin/tsgo -p tsconfig.build.json)
    npm --prefix packages/agent run build
    npm --prefix packages/session-backends/sqlite-node run build
    npm --prefix packages/protocol run build
    npm --prefix packages/client run build
    npm --prefix packages/server run build
    npm --prefix packages/coding-agent run build
    bun build --compile --no-compile-autoload-bunfig \
      ./packages/coding-agent/dist/bun/cli.js \
      ./packages/coding-agent/src/utils/image-resize-worker.ts \
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

    clipboardTarget=${if stdenv.hostPlatform.isAarch64 then "linux-arm64-gnu" else "linux-x64-gnu"}
    mkdir --parents "$packageDirectory/node_modules/@mariozechner"
    cp --recursive node_modules/@mariozechner/clipboard "$packageDirectory/node_modules/@mariozechner/"
    cp node_modules/@mariozechner/clipboard-"$clipboardTarget"/clipboard."$clipboardTarget".node \
      "$packageDirectory/node_modules/@mariozechner/clipboard/"

    makeWrapper "$packageDirectory/pi" "$out/bin/pi" \
      --prefix PATH : ${lib.makeBinPath [ fd ripgrep ]} \
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
