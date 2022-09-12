{ lib
, stdenv
, fetchurl
, appimageTools
}:
appimageTools.wrapType2 {
  name = "immersed";
  src = fetchurl {
    url = "https://static.immersed.com/dl/Immersed-x86_64.AppImage";
    hash = "sha256-4gplEG/P66YYkbpOEs+C83/oHHhviZMh4v4TEvnBnAU=";
  };
  extraPkgs = pkgs: [ pkgs.pulseaudio ];
}

