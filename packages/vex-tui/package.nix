{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "vex-tui";
  version = "2.0.2";

  src = fetchFromGitHub {
    owner = "CodeOne45";
    repo = "vex-tui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-wmze6OkX8Oxm+HtHBWo1+oSVDUR4PWWTTW/Ldu5z8pc=";
  };

  vendorHash = "sha256-jE53+VEjj5E5G2Yycwb8NDA8vDtoUtarrQgZ9ULyVh0=";

  meta = {
    description = "Beautiful, fast, and feature-rich terminal-based Excel and CSV viewer and editor";
    homepage = "https://github.com/CodeOne45/vex-tui";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.bobvanderlinden ];
    mainProgram = "vex";
  };
})
