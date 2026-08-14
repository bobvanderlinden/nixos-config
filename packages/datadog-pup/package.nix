{
  lib,
  rustPlatform,
  fetchFromGitHub,
  fetchpatch,
}:
let
  pup = rustPlatform.buildRustPackage rec {
    pname = "datadog-pup";
    version = "unstable-2026-08-14";

    src = fetchFromGitHub {
      owner = "DataDog";
      repo = "pup";
      rev = "3374b8d1d3fa8056d5b290c477846660d1877749";
      hash = "sha256-EETtgS9ubFa8aQxefXyZiu8CNfqf7PpyqCCpz07Ld9I=";
    };

    cargoHash = "sha256-IhGAykqkxTnLtbHW0hh3a/7SkY5XxaA/ZP9czfXWPrM=";

    doCheck = false;

    meta = {
      description = "AI-agent-ready command-line interface for Datadog's observability platform";
      homepage = "https://github.com/DataDog/pup";
      license = lib.licenses.asl20;
      maintainers = [ ];
      mainProgram = "pup";
      platforms = lib.platforms.linux;
    };
  };
in
pup.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [
    (fetchpatch {
      url = "https://github.com/DataDog/pup/pull/724.patch";
      hash = "sha256-hYiAvvi67XTRajeDSCuocqJOumRtVy4Xzl0M6erJhEo=";
    })
  ];
})
