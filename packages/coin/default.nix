{pkgs}: let
  coinSound = pkgs.fetchurl {
    url = "https://themushroomkingdom.net/sounds/wav/smw/smw_coin.wav";
    sha256 = "18c7dfhkaz9ybp3m52n1is9nmmkq18b1i82g6vgzy7cbr2y07h93";
  };
in
  pkgs.writeShellScriptBin "coin" ''
    ${pkgs.sox}/bin/play --no-show-progress ${coinSound}
  ''
