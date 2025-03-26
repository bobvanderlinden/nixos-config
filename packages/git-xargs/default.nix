{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule {
  # https://github.com/gruntwork-io/git-xargs
  src = fetchFromGitHub {
    owner = "gruntwork-io";
    repo = "git-xargs";
    rev = "v0.1.16";
    hash = "";
  };
  meta = with lib; {
    description = "A tool for running commands across multiple git repositories";
    homepage = "https://github.com/gruntwork-io/git-xargs";
    license = licenses.asl20;
    maintainers = [ maintainers.bobvanderlinden ];
  };
}
