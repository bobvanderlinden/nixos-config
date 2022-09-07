{pkgs, system, inputs}: let
  mkRubyShell = {ruby}:
    with pkgs;
      mkShell {
        nativeBuildInputs = with pkgs; [
          ruby
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

  rubyPackages = inputs.nixpkgs-ruby.packages.${system};
in {
  ruby-2_7 = mkRubyShell {ruby = rubyPackages.ruby-2_7;};
  ruby-3_0 = mkRubyShell {ruby = pkgs.ruby-3_0;};
  ruby-3_1 = mkRubyShell {ruby = pkgs.ruby-3_1;};
}
