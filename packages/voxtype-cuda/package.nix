{
  autoAddDriverRunpath,
  cudaPackages,
  voxtype,
}:

voxtype.overrideAttrs (oldAttrs: {
  pname = "voxtype-cuda";

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
