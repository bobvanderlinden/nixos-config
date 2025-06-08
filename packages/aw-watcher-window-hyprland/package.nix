{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  hyprland,
}:

rustPlatform.buildRustPackage rec {
  pname = "aw-watcher-window-hyprland";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "bobvanderlinden";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-7dfEwaub0wVy8QxMfxAmVd3htJ4S+9WOnru/LtnlzQg=";
  };

  cargoHash = "sha256-eA5MzNgTEtNNIHKGj3QG1TUhp1esBIU8Qou0SdoJczs=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  runtimeDependencies = [
    hyprland
  ];

  meta = with lib; {
    description = "ActivityWatch watcher for tracking active window and workspace in Hyprland";
    homepage = "https://github.com/bobvanderlinden/aw-watcher-window-hyprland";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    mainProgram = "aw-watcher-window-hyprland";
    platforms = platforms.linux;
  };
}
