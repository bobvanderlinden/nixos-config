{
  lib,
  stdenvNoCC,
  fetchurl,
  testers,
}:

let
  version = "4.11.0";
  releases = {
    aarch64-darwin = {
      platform = "macOS_arm64";
      hash = "sha256-1mBJaSQksekQFN95KzgABwnFNhQp4/F/U+ZHINiuq7w=";
    };
    aarch64-linux = {
      platform = "linux_arm64";
      hash = "sha256-uK5HrlVFJAzc0h7IWkClbeom5/BzIHM6blJmGIwbZtw=";
    };
    x86_64-darwin = {
      platform = "macOS_amd64";
      hash = "sha256-mnUgu7po+ZQ+AQ4+HLc3X6sLSTW07cWqS82HzQQC4d4=";
    };
    x86_64-linux = {
      platform = "linux_amd64";
      hash = "sha256-+uvSXY0nUTuVqqu/2jtz+AxwWcAaU73mXc8um6b4mvs=";
    };
  };
  release = releases.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "slack-cli";
  inherit version;

  src = fetchurl {
    url = "https://github.com/slackapi/slack-cli/releases/download/v${version}/slack_cli_${version}_${release.platform}.tar.gz";
    inherit (release) hash;
  };
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/slack "$out/bin/slack"
    install -Dm644 LICENSE "$out/share/licenses/slack-cli/LICENSE"

    runHook postInstall
  '';

  passthru.tests.version = testers.testVersion {
    package = finalAttrs.finalPackage;
    version = "v${version}";
    command = ''HOME="$TMPDIR" slack version'';
  };

  meta = {
    description = "Official command-line interface for building Slack apps";
    homepage = "https://github.com/slackapi/slack-cli";
    license = lib.licenses.asl20;
    mainProgram = "slack";
    platforms = builtins.attrNames releases;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
