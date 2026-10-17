{
  buildNpmPackage,
  fetchurl,
  lib,
  worktree,
}:
buildNpmPackage rec {
  pname = "pi-subagents";
  version = "0.77.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/pi-subagents/-/pi-subagents-${version}.tgz";
    hash = "sha256-SSJqQUyr7lbzddr6VQHykpvyS6lMSySR4+ZmxbrkTQc=";
  };

  # The published package has no lock file. Lock only its runtime dependencies;
  # Pi supplies the SDK peer dependencies when it loads this local package.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    substituteInPlace src/runs/shared/worktree.js \
      --replace-fail '@worktree@' '${worktree}/bin/worktree'
  '';
  patches = [ ./worktree-command.patch ];
  npmDepsHash = "sha256-inCNTNSOUuwh6r/SRvTcGODNx1pWDwvg92LBeLZxx3g=";
  npmFlags = [ "--legacy-peer-deps" ];
  npmInstallFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir --parents "$out/lib/node_modules/pi-subagents"
    cp --recursive . "$out/lib/node_modules/pi-subagents/"
    runHook postInstall
  '';

  meta = {
    description = "Pi subagents with the shared worktree command";
    homepage = "https://github.com/nicobailon/pi-subagents";
    license = lib.licenses.mit;
  };
}
