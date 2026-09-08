{
  lib,
  deno,
  fetchFromGitHub,
  makeWrapper,
  stdenvNoCC,
}:
let
  pname = "oauth2cli";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "bobvanderlinden";
    repo = pname;
    rev = "4fc8ca0db7944db3fd21f95156bfce2a59a1e2c8";
    hash = "sha256-VmSe/7P5ZWonKzjrpC8ur69Nd7Gy/bSimjaRnrCPU6o=";
  };

  denoDeps = stdenvNoCC.mkDerivation {
    pname = "${pname}-deps";
    inherit version src;

    nativeBuildInputs = [ deno ];

    outputHashMode = "recursive";
    outputHash = "sha256-ReHOMzfQQOJQAznx3vXB09iEhTx01C9hMLHDAYdsjIw=";
    outputHashAlgo = "sha256";

    buildPhase = ''
      export DENO_DIR="$out"
      deno cache --frozen --lock=deno.lock main.ts
    '';

    installPhase = "true";
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    makeWrapper ${deno}/bin/deno "$out/bin/oauth2cli" \
      --set DENO_DIR ${denoDeps} \
      --add-flags "run --cached-only --no-code-cache --frozen --lock=${src}/deno.lock --allow-net --allow-read --allow-write --allow-run ${src}/main.ts"
  '';

  meta = {
    description = "CLI for handling OAuth2 for curl";
    homepage = "https://github.com/bobvanderlinden/oauth2cli";
    license = lib.licenses.mit;
    mainProgram = pname;
  };
}
