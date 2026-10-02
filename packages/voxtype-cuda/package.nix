{
  autoAddDriverRunpath,
  cudaPackages,
  fetchpatch,
  voxtype,
}:

voxtype.overrideAttrs (oldAttrs: {
  pname = "voxtype-cuda";

  patches = (oldAttrs.patches or [ ]) ++ [
    (fetchpatch {
      url = "https://github.com/bobvanderlinden/voxtype/commit/960577e75b66710bef8b93b3e4d80876c6b0a8e0.patch";
      hash = "sha256-TW1prMrhJggEYVFQA6jExcoHn/ScO7DxCXXQQHOv5/g=";
    })
  ];

  cargoBuildFeatures = (oldAttrs.cargoBuildFeatures or [ ]) ++ [ "gpu-cuda" ];
  cargoCheckFeatures = (oldAttrs.cargoCheckFeatures or [ ]) ++ [ "gpu-cuda" ];
  NIX_LDFLAGS = (oldAttrs.NIX_LDFLAGS or "") + " -L${cudaPackages.cuda_cudart}/lib/stubs";
  doInstallCheck = false;

  nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
    autoAddDriverRunpath
    cudaPackages.cuda_nvcc
  ];

  buildInputs =
    oldAttrs.buildInputs
    ++ (with cudaPackages; [
      cccl
      cuda_cudart
      libcublas
    ]);
})
