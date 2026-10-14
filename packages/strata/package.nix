{
  lib,
  fetchFromGitHub,
  cudaPackages_13_0,
  autoAddDriverRunpath,
  cmake,
  ninja,
  makeWrapper,
  python3,
  writeText,
}:
let
  cudaPackages = cudaPackages_13_0;
  llamaSource = fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = "3cf03257f219afbe7334045ff7c6a06ac68c627d";
    hash = "sha256-SRGoXa+4ACBCB3eaG9XFYhMN1i0FyPEy9Rrer+dFGYI=";
  };
  python = python3.withPackages (packages: [
    packages.numpy
    packages.jinja2
    packages.regex
    packages.pyyaml
    packages.tqdm
    packages.requests
    packages.pillow
    packages.psutil
  ]);
  setupLauncher = writeText "strata-nix-setup.py" ''
    import os
    import sys
    from pathlib import Path

    # Upstream setup prepares the model. Nix supplies the engine and dependencies,
    # so setup must not install pip packages or download/build another engine.
    sys.path.insert(0, os.getcwd())
    import setup

    engine = Path(os.environ["STRATA_NIX_ENGINE"])
    llama = Path("${llamaSource}")
    setup.pip_install = lambda packages, description: setup.ok(description + " supplied by Nix")
    setup.get_llama_cpp = lambda: llama
    setup.engine_step = lambda arguments, gpu, hip, amd, toolkit, vision: (
        llama, engine, {"source": "local", "version": "0.1.44"}, [], gpu, vision
    )
    sys.exit(setup.main())
  '';
in
cudaPackages.backendStdenv.mkDerivation (finalAttrs: {
  pname = "strata";
  version = "0.1.44";

  src = fetchFromGitHub {
    owner = "Niko1221";
    repo = "Strata";
    rev = "ed4773eb7c8f1f1531ba2bc70e0e1987de2661af";
    hash = "sha256-Yjlu2tRBYrabTp/hZvZh4QECJZSTJe8Bh2P6MqvQdX0=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    makeWrapper
    autoAddDriverRunpath
    cudaPackages.cuda_nvcc
  ];
  buildInputs = [
    cudaPackages.cccl
    cudaPackages.cuda_cudart
    cudaPackages.libcublas
  ];

  cmakeFlags = [
    "-DSTRATA_ENABLE_CUDA=ON"
    "-DSTRATA_BUILD_TESTS=OFF"
    "-DSTRATA_PORTABLE=ON"
    "-DSTRATA_GGML_DIR=${llamaSource}"
    "-DCMAKE_CUDA_ARCHITECTURES=120"
    "-DBUILD_SHARED_LIBS=OFF"
  ];
  ninjaFlags = [ "strata" ];

  installPhase = ''
    runHook preInstall
    mkdir --parents "$out/libexec/strata/engine" "$out/share/strata" "$out/bin"
    install --mode=755 strata "$out/libexec/strata/engine/strata"
    if [[ -f libstrata_kq.so ]]; then
      install --mode=755 libstrata_kq.so "$out/libexec/strata/engine/"
    fi
    cp --recursive ../setup.py ../CMakeLists.txt ../requirements.txt ../serve ../tools ../data ../include ../src ../third_party "$out/share/strata/"
    ln --symbolic ${llamaSource} "$out/share/strata/third_party/llama.cpp"

    makeWrapper ${python}/bin/python "$out/bin/strata-setup" \
      --add-flags ${setupLauncher} \
      --set STRATA_NIX_ENGINE "$out/libexec/strata/engine" \
      --prefix PYTHONPATH : ${llamaSource}/gguf-py
    makeWrapper ${python}/bin/python "$out/bin/strata-server" \
      --add-flags "$out/share/strata/serve/server.py --engine strata" \
      --prefix PYTHONPATH : ${llamaSource}/gguf-py
    runHook postInstall
  '';

  passthru = { inherit python; };
  meta = {
    description = "Qwen3.8-Flash-Next inference with GPU expert caching and speculative decoding";
    homepage = "https://github.com/Niko1221/Strata";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "strata-server";
  };
})
