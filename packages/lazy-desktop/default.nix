{ lib
, stdenv
, runCommand
, nix-index
, desktop-file-utils
}:
let 
  nix-index-database = builtins.fetchurl {
    url = "https://github.com/nix-community/nix-index-database/releases/download/2024-02-11-030837/index-x86_64-linux";
    sha256 = "1zc6wraxrjrm93z71244ly07jbdg2fq2g3dqzf02n55z410cblgv";
  };
in
stdenv.mkDerivation {
  name = "lazy-desktop";
  buildInputs = [ nix-index desktop-file-utils ];
  dontUnpack = true;
  dontBuild = true;
  installPhase = ''
mkdir -p $out/share/applications
ln -s ${nix-index-database} files
nix-locate \
  --db . \
  --top-level \
  --minimal \
  --regex \
  '/share/applications/.*\.desktop$' \
  | while read -r package
  do
    cat > $out/share/applications/"$package.desktop" << EOF
[Desktop Entry]
Version=1.0
Name=$package
Type=Application
Exec=nix run "nixpkgs#$package" -- %F
EOF
    desktop-file-validate $out/share/applications/"$package.desktop"
  done
  '';
  meta = {
    platforms = lib.platforms.all;
  };
}
