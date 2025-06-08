{
  lib,
  buildGoModule,
  fetchFromGitHub,
# git,
}:
let
  pname = "git-xargs";
  version = "0.1.16";
in
buildGoModule {
  inherit pname version;
  src = fetchFromGitHub {
    owner = "gruntwork-io";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-43HXWV5qrzZL0exsNtpYhJj/wvEWIw8tX5JGdHIZYhY=";
  };
  vendorHash = "sha256-PsNCZRz+iUuZN5YUhkitItvx2SQMvTX/t8L/XthwaQs=";
  doCheck = false;
  # nativeCheckInputs = [ git ];
  # preCheck = ''
  #   export HOME=$TMPDIR
  #   git config --global user.email "test@example.com"
  #   git config --global user.name "Test User"
  # '';
  meta = with lib; {
    description = "A command-line tool for making updates across multiple Github repositories";
    homepage = "https://github.com/gruntwork-io/git-xargs";
    license = licenses.asl20;
    maintainers = [ maintainers.bobvanderlinden ];
  };
}
