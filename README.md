# nixos-config

This repository includes the Nix configuration for my laptop.

It includes the following:

- A flake-based configuration (see [flake.nix](flake.nix))
- [NixOS](https://nixos.org/) configuration (see [configuration.nix](system/configuration.nix))
- [home-manager](https://github.com/nix-community/home-manager#home-manager-using-nix) configuration (see [home](home/default.nix))
- Custom NixOS modules (see [system/modules/](system/modules/))
- Custom home-manager modules (see [home/modules/](home/modules/))
- Custom packages (see [packages/](packages/))
- [Pi](https://github.com/badlogic/pi-mono) extensions (see [home/profiles/pi/extensions/](home/profiles/pi/extensions/))
- [Quickshell](https://quickshell.org/) configuration (see [home/profiles/quickshell/](home/profiles/quickshell/))
- Do not expect this configuration to work for your system as-is

## Usage

To switch to a new system+home configuration I usually run:

```sh
nix run --impure .#switch
```

Which does the following:

- Switch to new configuration for home-manager
- Switch to new configuration for NixOS
- Builds configuration using [`nom`](https://github.com/maralorn/nix-output-monitor) for more insightful output.
- Pass `--plain` to use Nix's raw log output instead, which is suitable for non-interactive tools and agents: `nix run --impure .#switch -- --plain`.
- Asks for `sudo` only when system configuration has actually changed.
- Plings when actually switching system configuration.

This is similar to using the `home-manager` and `nixos-rebuild` tools:

```console
$ home-manager switch --impure --flake .
$ nixos-rebuild --impure --flake . switch --use-remote-sudo
```

To update nixpkgs and others I usually do:

```sh
nix flake update
```
