{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
}:
appimageTools.wrapType2 {
  name = "immersed";
  src = fetchurl {
    url = "https://static.immersed.com/dl/Immersed-x86_64.AppImage";
    hash = "sha256-4gplEG/P66YYkbpOEs+C83/oHHhviZMh4v4TEvnBnAU=";
  };
  extraPkgs = pkgs: [ pkgs.pulseaudio ];

  meta = with lib; {
    description = "A VR-based productivity and meeting app that you can get on the Oculus Quest platform";
    homepage = "https://immersed.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ bobvanderlinden ];
  };
}
