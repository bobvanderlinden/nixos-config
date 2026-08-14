---
name: nix
description: Find Nix packages and use Nix commands. Load whenever you intend to run `nix`, install a package, or identify the package that provides an executable.
---

## Find packages

Never use `nix search nixpkgs <package-name>`.

1. When you know the executable name, search the Nix package index first:

   ```bash
   nix-locate --minimal --at-root /bin/<executable>
   ```

2. Otherwise, query the NixOS Search backend. It requires the public basic-auth value used by the browser: without it the endpoint responds with HTTP 401. This is the minimal verified `xh` request for an exact package attribute; replace `cowsay` with the package name:

   ```bash
   xh --ignore-stdin POST 'https://search.nixos.org/backend/latest-50-nixos-unstable/_search' \
     authorization:'Basic YVdWU0FMWHBadjpYOGdQSG56TDUyd0ZFZWt1eHNmUTljU2g=' \
     content-type:application/json \
     --raw '{"query":{"bool":{"filter":[{"term":{"type":"package"}},{"term":{"package_attr_name":"cowsay"}}]}}}'
   ```

   `--ignore-stdin` prevents `xh` from treating the agent's standard input as a second request body.

3. Use the resulting `package_attr_name` with `nix run`, `nix shell`, or configuration changes as appropriate.
