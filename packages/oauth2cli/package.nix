{
  lib,
  deno,
  fetchFromGitHub,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "oauth2cli";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "bobvanderlinden";
    repo = finalAttrs.pname;
    rev = "1880fc21fa6717b25e0f7c1f104ebc7409418572";
    hash = "sha256-q2ET74ERO7oVbkui/ClCVWkIyjiEmBxdnLtEifAwavg=";
  };

  nativeBuildInputs = [ deno ];

  outputHashMode = "recursive";
  outputHash = "sha256-rjs7gtN0bI3I8kTVCgrAmz6+n9rVVBvznZsZAxHPw24=";
  outputHashAlgo = "sha256";

  buildPhase = ''
    export DENO_DIR="$TMPDIR/deno"
    deno compile --frozen --lock=deno.lock \
      --allow-net --allow-read --allow-write --allow-run --allow-env --allow-ffi --allow-sys \
      --output "$out/bin/oauth2cli" \
      main.ts
  '';

  installPhase = "true";

  meta = {
    description = "CLI for handling OAuth2 for curl";
    homepage = "https://github.com/bobvanderlinden/oauth2cli";
    license = lib.licenses.mit;
    mainProgram = finalAttrs.pname;
  };
})
