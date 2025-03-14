{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.programs.mergiraf;
  mergiraf = "${cfg.package}/bin/mergiraf";
in
{
  options = {
    programs.mergiraf = {
      enable = lib.mkEnableOption "mergiraf";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.mergiraf;
        defaultText = lib.literalExample "pkgs.mergiraf";
        description = "mergiraf package to use";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    programs.git.extraConfig = {
      merge.mergiraf = {
        name = "mergiraf";
        driver = "${mergiraf} merge --git %O %A %B -s %S -x %X -y %Y -p %P -l %L";
      };
    };

    xdg.configFile."git/attributes".source = pkgs.runCommand "mergiraf-git-attributes" { } ''
      ${mergiraf} languages --gitattributes > $out
    '';
  };
}
