{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "kmp-lsp";
  version = "0.25.0";

  src = fetchFromGitHub {
    owner = "Hessesian";
    repo = pname;
    rev = "da453afcdef889f1f8e0ce8976bc18b67f4add7f";
    hash = "sha256-/z/N0pZwZgmHoVv3ss2se64Wqa0gyMoFKQUJn5OsTZI=";
  };

  cargoHash = "sha256-+pC8wnNCKDV0Hdnwl9t0abNgeFsG8XSABQkzXE9nW44=";

  doCheck = false;

  meta = {
    description = "Kotlin, Java, and Swift language server";
    homepage = "https://github.com/Hessesian/kmp-lsp";
    license = lib.licenses.mit;
    mainProgram = pname;
    platforms = lib.platforms.linux;
  };
}
