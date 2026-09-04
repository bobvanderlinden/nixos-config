# nixos-config

This repository includes the Nix configuration for my laptop.

It includes the following:

- A flake-based configuration (see [flake.nix](flake.nix))
- [NixOS](https://nixos.org/) configuration (see [configuration.nix](system/configuration.nix))
- [home-manager](https://github.com/nix-community/home-manager#home-manager-using-nix) configuration (see [home](home/default.nix))
- Custom NixOS modules (see [system/modules/](system/modules/))
- Custom home-manager modules (see [home/modules/](home/modules/))
- Custom packages (see [packages/](packages/))
- Do not expect this configuration to work for your system as-is

## Usage

To switch to a new system+home configuration I usually run:

```sh
nix run .#switch
```

Which does the following:

- Switch to new configuration for home-manager
- Switch to new configuration for NixOS
- Builds configuration using [`nom`](https://github.com/maralorn/nix-output-monitor) for more insightful output.
- Asks for `sudo` only when system configuration has actually changed.
- Plings when actually switching system configuration.

This is similar to using the `home-manager` and `nixos-rebuild` tools:

```console
$ home-manager switch --flake .
$ nixos-rebuild --flake . switch --use-remote-sudo
```

To update nixpkgs and others I usually do:

```sh
nix flake update
```

## Installing `new-laptop`

Boot a NixOS USB stick in UEFI mode. Secure Boot must be disabled or in Setup
Mode for the first installed boot. Then run:

```sh
sudo nix run github:bobvanderlinden/nixos-config#install-new-laptop
```

The installer selects the only writable non-USB disk. If it finds more than
one, use a stable device path yourself:

```sh
sudo nix run github:bobvanderlinden/nixos-config#install-new-laptop -- \
  --disk /dev/disk/by-id/nvme-eui.0123456789abcdef
```

It prints the selected disk path, model, serial, WWN, memory-derived swap size,
and partition plan before accepting `ERASE`. It asks for a LUKS passphrase and
then runs `disko-install`. The layout uses `NIXOS-ESP`, `NIXOS-BOOT`, and
`NIXOS-LUKS` GPT labels, with encrypted `nixos/swap` and `nixos/root` logical
volumes.

The installer first installs a small bootstrap system. This keeps the large
Home Manager closure out of the installer USB's temporary `/nix/store`. On its
first boot, the bootstrap system waits for network access and rebuilds the full
`new-laptop` configuration on the encrypted disk. Inspect progress with:

```sh
journalctl --unit install-full-system --follow
```

Lanzaboote creates and enrolls Secure Boot keys during the first installed boot.
That boot is unsigned. Restart after enrollment to boot with Secure Boot.

`systems/new-laptop.nix` has a generic NVMe/NVIDIA baseline. After the first
boot, replace its kernel-module list with the result of
`nixos-generate-config` and set the final hostname.
