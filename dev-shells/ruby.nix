{pkgs, lib, system, inputs}: let
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
        ] ++ lib.optional (system == "x86_64-linux") [
          chromedriver
        ];
        WD_CHROME_PATH = lib.optionalString (system == "x86_64-linux") "${pkgs.chromium}/bin/chromium";
        FREEDESKTOP_MIME_TYPES_PATH = "${pkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml";
      };

  rubyPackages = inputs.nixpkgs-ruby.packages.${system};
in {
  ruby-2_7 = mkRubyShell {ruby = rubyPackages.ruby-2_7;};
  ruby-3_0 = mkRubyShell {ruby = pkgs.ruby_3_0;};
  ruby-3_1 = mkRubyShell {ruby = pkgs.ruby_3_1;};
}
