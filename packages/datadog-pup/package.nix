{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "datadog-pup";
  version = "1.6.6";

  src = fetchFromGitHub {
    owner = "DataDog";
    repo = "pup";
    rev = "v${version}";
    hash = "sha256-EN9r3hrqzkiS8h6M1mpqa5UZUEeGaR/zz8nT5UerSWY=";
  };

  cargoHash = "sha256-3NSQ3Yzwk1nmWzzGQkSaIaDEb5058Jg+6dNUhKlGIv0=";

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
