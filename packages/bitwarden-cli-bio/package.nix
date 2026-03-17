{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  bitwarden-cli,
}:

buildNpmPackage rec {
  pname = "bitwarden-cli-bio";
  version = "1.4.2";

  src = fetchFromGitHub {
    owner = "jeanregisser";
    repo = "bitwarden-cli-bio";
    rev = "v${version}";
    hash = "sha256-6/SOvO5ODgMyHMbStY5fDJH4uIxZNyIia7UvBUZ4ygw=";
  };

  npmDepsHash = "sha256-ITJcoBaKosnhRleLp8b5+W5WJ3aI3GFYt4KPPlghsyM=";

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/bwbio \
      --prefix PATH : ${lib.makeBinPath [ bitwarden-cli ]}
  '';

  meta = {
    description = "Bitwarden CLI with biometric unlock (Touch ID, Windows Hello, Linux Polkit)";
    homepage = "https://github.com/jeanregisser/bitwarden-cli-bio";
    license = lib.licenses.mit;
    mainProgram = "bwbio";
  };
}
