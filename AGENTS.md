# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## Repository Overview

This is a personal NixOS configuration repository using flakes for a laptop system (hostname: nac44250). It includes:

- **System Configuration**: NixOS system configuration in `system/configuration.nix`
- **Home Manager Configuration**: User environment configuration in `home/default.nix`
- **Custom Modules**: System modules in `system/modules/` and home-manager modules in `home/modules/`
- **Custom Packages**: Local package definitions in `packages/`
- **Flake-based Setup**: Uses patched nixpkgs with specific package overrides

## Key Architecture Patterns

### Flake Structure
- `flake.nix` defines inputs (nixpkgs, home-manager, lanzaboote, etc.) and outputs
- Uses patched nixpkgs with specific package fixes/downgrades
- Implements overlays for package customizations and workarounds
- Single-system configuration for laptop "nac44250"

### Module System
- System modules use the standard NixOS module system
- Home-manager modules extend user environment
- "Suites" pattern: `suites.single-user` provides common single-user configuration
- Custom modules in `system/modules/default.nix` export reusable functionality

### Package Management
- Custom packages in `packages/` directory, each in subdirectory with `default.nix`
- Packages include custom scripts (wl-screenrecord, coin, hypr-open) and package overrides
- Uses overlays to make custom packages available system-wide

## Common Development Commands

### Switching Configuration
```bash
# Switch to new system+home configuration (recommended)
nix run .#switch

# Switch only home-manager configuration
nix run .#switch-home

# Traditional approach (alternative)
home-manager switch --flake .
nixos-rebuild --flake . switch --use-remote-sudo
```

### Updates and Maintenance
```bash
# Update all flake inputs
nix flake update

# Garbage collection (automatic weekly via system config)
nix-collect-garbage --delete-older-than 30d
```

### Development Tools
```bash
# Enter development shell with nixfmt and nixd
nix develop

# Format Nix code
nixfmt .

# Build specific packages
nix build .#packages.x86_64-linux.<package-name>
```

### Testing Changes
- System changes require `sudo` and will prompt for confirmation
- Home-manager changes apply immediately to user environment
- The `switch` script uses `nom` (nix-output-monitor) for better build output

## Desktop Environment

Uses Hyprland window manager with:
- Waybar status bar
- Rofi launcher
- Flameshot screenshots
- Custom scripts for workspace-aware application launching

Username: bob.vanderlinden
Hostname: nac44250