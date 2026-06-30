{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "pup";
  version = "1.5.0";

  src = fetchFromGitHub {
    owner = "DataDog";
    repo = "pup";
    rev = "v${version}";
    hash = "sha256-9Jz3ft7XBOPQM1SolyBgSyvx8X8FNmbGOGduBDJRZYw=";
  };

  cargoHash = "sha256-kWSeNsDr+Ilg2Es7R8i3EhQiot8rbjWAl/Big3vmdjA=";

  # The v1.5.0 test suite fails to compile: src/commands/auth.rs references a
  # `token` function that is not in scope in the test module. This is an
  # upstream bug unrelated to packaging; the release binary builds fine.
  doCheck = false;

  meta = {
    description = "AI-agent-ready command-line interface for Datadog's observability platform";
    homepage = "https://github.com/DataDog/pup";
    license = lib.licenses.asl20;
    maintainers = [ ];
    mainProgram = "pup";
    platforms = lib.platforms.linux;
  };
}
