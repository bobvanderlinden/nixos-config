# Share nixpkgs' source build between the desktop and server packages.
{
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_11,
  t3code,
}:
let
  version = "0.1.6";
  unwrapped = t3code.unwrapped.overrideAttrs (
    finalAttrs: _previousAttrs: {
      inherit version;
      src = fetchFromGitHub {
        owner = "pingdotgg";
        repo = "t3code";
        tag = "v${version}";
        hash = "sha256-GWO+/gJWLu9GUwZCbmrBYIVn9Y7N8PwXrjQYFLOtmWk=";
      };
      pnpmDeps = fetchPnpmDeps {
        pnpm = pnpm_11;
        inherit (finalAttrs)
          pname
          version
          src
          pnpmWorkspaces
          ;
        fetcherVersion = 4;
        hash = "sha256-gPQ9D1g2wV9htQuvxDK4EJJihF6sbras7q2O3XfCVUE=";
      };
    }
  );
  resourceMonitor = t3code.resourceMonitor.overrideAttrs {
    inherit (unwrapped) version src;
  };
in
t3code.override {
  t3code-unwrapped = unwrapped;
  t3code-resource-monitor = resourceMonitor;
  enableCodex = false;
  enableGitHub = false;
}
