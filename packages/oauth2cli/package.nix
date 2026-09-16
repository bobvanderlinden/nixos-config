{
  lib,
  deno,
  fetchFromGitHub,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "oauth2cli";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "bobvanderlinden";
    repo = finalAttrs.pname;
    rev = "0de226159512052660dd944acaae82525a664bbb";
    hash = "sha256-Vkccm84y25beXAzLj29NyvnaHrZu3E0B2SkjVDgDTjA=";
  };

  nativeBuildInputs = [ deno ];

  outputHashMode = "recursive";
  outputHash = "sha256-7NO3ty07LYKBKXrohVz8wqGNK+9s6BiMBj48wlbBUfI=";
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
