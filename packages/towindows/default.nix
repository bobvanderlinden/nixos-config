{ stdenv, ... }:
stdenv.mkDerivation rec {
  name = "towindows-${version}";
  version = "1.0";
  unpackPhase = "true";
  buildPhase = ''
    gcc -o towindows -DPREFIX=\"$out\" ${./towindows.c}
  '';
  installPhase = ''
    install -Dm755 towindows $out/bin/towindows
    install -Dm755 ${./towindows.sh} $out/bin/towindows.sh
  '';
}
