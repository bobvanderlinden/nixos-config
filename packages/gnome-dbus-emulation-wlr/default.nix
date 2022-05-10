{
  lib,
  stdenv,
  fetchFromGitLab,
  bundlerEnv,
  makeWrapper,
  ruby_2_7,
}:
stdenv.mkDerivation rec {
  pname = "gnome-dbus-emulation-wlr";
  version = "unstable-2022-02-21";

  # src = fetchFromGitLab {
  #   owner = "jamedjo";
  #   repo = "gnome-dbus-emulation-wlr";
  #   rev = "c1314b12de214505af4b1b6007686ccc91692892";
  #   hash = "sha256-ghDI08f/1avP+HUpQAoZjZ9bY0FILXKquRvZfkrgpTU=";
  # };
  src = ./src;

  gems = bundlerEnv {
    name = "${pname}-gems-${version}";
    inherit version;
    ruby = ruby_2_7;
    gemdir = src;
    gemset = ./gemset.nix;
  };

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    makeWrapper "${gems}/bin/bundle" $out/bin/gnome-dbus-emulation-wlr \
      --add-flags "exec ${src}/gnome_dbus_emulation.rb" \
  '';
}
