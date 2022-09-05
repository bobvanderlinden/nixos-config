{pkgs, ...}: let
  mkRubyShell = {version}:
    with pkgs;
      mkShell {
        nativeBuildInputs = with pkgs; [
          pkgs."ruby_${version}"
          mysql.client
          libmysqlclient
          sqlite
          automake
          pkg-config
          augeas
          libxml2
          github-changelog-generator
          chromedriver
        ];
        WD_CHROME_PATH = "${pkgs.chromium}/bin/chromium";
        FREEDESKTOP_MIME_TYPES_PATH = "${pkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml";
      };
in {
  ruby-3_0 = mkRubyShell {version = "3_0";};
  ruby-3_1 = mkRubyShell {version = "3_1";};
}
