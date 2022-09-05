# nixos-config

This repository includes the configuration for my laptop. It is based on [Nix flakes](https://nixos.wiki/wiki/Flakes).

The configuration is split into [system](#system) configuration based on [NixOS](https://nixos.org/) and [home](#home) configuration based on [home-manager](https://github.com/nix-community/home-manager#home-manager-using-nix).

## System

Configuration for my system can be found under [system/](system/).

To switch my system to a new configuration I usually do:

```sh
nixos-rebuild --use-remote-sudo --flake . boot
```

This creates a new boot entry with the new configuration. Rebooting my system will switch to the new configuration.

Due to suspending my laptop upgrades usually didn't switch my kernel version, which resulted in staying on the same kernel for long period of time. I opted for booting into new versions to avoid such situations.

The [home](#home) configuration is also used in the system configuration. That way the home configuration is also applied when I update the system configuration.

Some of the system configuration is split into modules. These can be found under [system/modules/](system/modules/).

## Home

Configuration for my home directory / dotfiles can be found under [home/](home/).

To switch to a new configuration I usually do:

```sh
home-manager --flake . switch
```

## Development shell

My system and home configurations are based on nixos-unstable. For development I often need to rely on language-specific package managers that sometimes like to build their own native dependencies. To avoid needing to rebuild these dependencies after system upgrades, I like to have development shells that have a stable environment.

I have development shells for the following languages available with various versions:

- [Java](shells/java.nix)
- [Node](shells/node.nix)
- [ruby](shells/ruby.nix)

You can enter a shell using for example:

```sh
nix develop github:bobvanderlinden/nixos-config#java-8
nix develop github:bobvanderlinden/nixos-config#node-16
nix develop github:bobvanderlinden/nixos-config#ruby-3_1
```

More conveniently you can use [direnv](https://direnv.net/) with [support for Nix](https://github.com/nix-community/nix-direnv) to make projects always use such an environment or share with the environment with a team.

In a project, create a file `.envrc` containing:

```sh
use flake github:bobvanderlinden/nixos-config#java-8
```

## Updating

To update the Nix flake lock file:

```sh
nix flake update
```
