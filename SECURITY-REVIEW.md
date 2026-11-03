# Security review of nac54003

## Scope

Reviewed the NixOS and Home Manager configuration, enabled system and user
units, user autostart entries, listening sockets, generated firewall rules,
Secure Boot status and enrolled certificate names, and block-device layout.
This is a configuration review, not a forensic examination or proof that the
machine is uncompromised. Reading live firewall tables and verifying the ESP
require administrator authentication. The privileged checks timed out; live
firewall tables and EFI signatures remain unverified. Normal key enrollment
was attempted and refused because firmware Setup Mode is disabled. No firmware
keys changed.

## Changes

- Removed the stale `electron-25.9.0` and `electron-39.8.10` exceptions from
  `system/profiles/laptop.nix`. The installed system and Home Manager closures
  contain Electron 43.8.3 and 44.9.3 instead. A full configuration build without
  the exceptions passed before the separate Nix source patch was added.
- Prepared nono wrappers for the `pi` and `pi-bolt` CLI commands. Both launch,
  but direct 1Password desktop authentication remains blocked by `no_new_privs`.
  Do not switch expecting full MediKitRequest compatibility yet. See
  `home/profiles/pi/README.md` for permissions and limitations.
- Added `patches/nix-directory-opath.patch` for the Nix 2.35 Landlock regression,
  with its source and regression tests. The workarounds overlay applies it to
  Determinate Nix. Both the host configuration and the Pi launcher select it.
  The patched package built successfully. The nono regression test passes:
  pure and impure evaluation, permitted reads/imports/listings, and permitted
  symlinks work. Reading `/`, denied directories, denied files, and symlinks
  into denied files still fails. This changes Nix, not the separate Determinate
  Nixd supervisor. It has not been activated.

## Nono compatibility checks before activation

The built wrappers were tested without switching the host configuration:

- Both `pi --version` and `pi-bolt --version` report Pi-Bolt 1.0.7.
- Starting from the home directory is refused.
- In MediKitRequest, the sandbox discovers exactly the same 15 skill names and
  paths as the unsandboxed baseline, including the parent MediTools skills.
- `/nix-session add hello` succeeds and the following shell command runs `hello`.
  The executable selected by the sandbox is patched Determinate Nix 3.24.1.
- The Docker API and `docker compose ps` work. Starting an isolated container
  from the existing database image, with no network or mounts, succeeds and
  the container is removed afterward. This does not test rebuilding or
  recreating the whole MediKitRequest stack.
- `op vault list` fails with a desktop connection reset. The Aidbox license is
  not loaded by the project environment. Full MediKitRequest compatibility is
  therefore not established. Fix credential handling before enabling this as
  the default workflow.
- The direnv regression tests pass, including keeping the sandbox Nix first on
  PATH after loading a project environment.

## Administrative access and persistence

- Nix trusts root only. Untrusted cache warnings are expected and are not a
  reason to add the desktop user back to `trusted-users`.
- SSH is disabled. The evaluated sudo rules require a password for wheel;
  there are no configured `NOPASSWD` rules. Wheel still has unrestricted
  administrative access after authentication, including `SETENV`.
- The installed polkit rules do not grant arbitrary administrative actions.
  They do grant NetworkManager and ModemManager actions to `networkmanager`
  members without authentication. The desktop user belongs to this group.
- The enabled user services inspected resolve to Home Manager or system store
  files. No unmanaged regular unit files were found under
  `~/.config/systemd/user`. These user-owned symlinks can still be replaced by
  any process running as this user.
- The unmanaged autostart entries inspected are Bitwarden and a disabled
  Gammastep indicator. Their executable paths point into the Nix store.
- No enabled `nix-update` service was found. NixOS automatic upgrades are
  disabled. Store-backed service definitions do not protect writable shell
  startup files, project hooks, or agent extensions from future persistence.

## Firewall and listening services

The firewall service is active. Both the evaluated configuration and the
installed start script have these incoming exceptions for IPv4 and IPv6:

- TCP 53317 and UDP 53317 for LocalSend, on every interface.
- UDP 5353 for mDNS, on every interface.
- Loopback, established/related traffic, ICMPv4 echo requests, required ICMPv6,
  and DHCPv6 client traffic.

Only loopback is a trusted interface. No PostgreSQL or Aidbox exception is
configured. Other incoming traffic reaches the drop rule. This describes the
generated rules; it is not an authenticated dump of the live kernel rules or
a remote port scan. Outgoing traffic is not filtered.

PostgreSQL 5432 and Aidbox 8888 currently listen on all IPv4 and IPv6 interfaces
through rootless Docker. Bind them to `127.0.0.1` in MediKitRequest as a separate
project change. They should not rely solely on the firewall. The rootless
daemon does not install rootful Docker's host firewall bypass rules.

Pi-web 31415, T3 Code 3773, the local model server 8080, and Phonon 8010 listen
on loopback. LLMNR listens on 5355 but has no incoming firewall exception.
Disable LLMNR if it is unnecessary. Restrict LocalSend and mDNS to trusted
interfaces or networks if they are not needed on public Wi-Fi.

## Remaining risks worth addressing

1. Stop automatically trusting new `.envrc` files in
   `home/profiles/pi/extensions/direnv.ts`. It currently runs `direnv allow`
   without human approval. A repository's environment file is executable code.
2. Reduce credentials loaded by MediKitRequest's `.envrc`. Agent processes
   inherit them, and allowing `op` deliberately preserves credential access.
3. For a stronger agent boundary, use a separate identity with no Docker API,
   isolated Pi state, and no host MCP command brokers. The compatible nono
   profile is filesystem confinement with explicit escape-capable services,
   not complete isolation from the user's files or secrets. Pi-web is not
   covered by the CLI wrapper.
4. Reconsider desktop membership in `input` and the `ydotool` configuration.
   Raw input access can permit key capture or injection independently of
   ordinary application permissions.
5. Remove blanket Thunderbolt authorization and replace the udev rule granting
   wheel access to all USB/MMC disks with device-specific rules where possible.
   Avoid world-writable USB devices unless a particular device needs them.
6. Consider `sudo` timestamp timeout zero and firmware administrator protection.
   These involve usability choices and were not changed by this review.
7. Add root-owned monitoring for new or changed user services, autostart entries,
   shell startup files, and agent extensions. Keep an approved baseline and
   review alerts. Monitoring does not prevent credential theft.

## Disk encryption and Secure Boot

The root filesystem and disk swap are inside LUKS. `/boot` and the EFI system
partition are unencrypted. Secure Boot is disabled. The enrolled certificate
names initially showed HP and Microsoft keys only, not the local sbctl key.
Setup Mode was disabled. A nonempty dbx is present.

Lanzaboote, key generation, and automatic enrollment preparation are configured.
The preparation service creates Microsoft-inclusive authentication files under
`/boot/efi/loader/keys/auto`. That configuration alone does not prove the files
exist now or that firmware has enrolled them.

Do not simply turn on enforcement with only the factory keys. First verify the
bootloader and generation EFI signatures as root, keep a recovery USB and the
LUKS recovery credential available, and enroll the local key. Firmware may
require entering Setup Mode by removing the Platform Key. Do not clear every
Secure Boot key or erase dbx. Preserve Microsoft and firmware keys needed for
Option ROMs and updates.

After enrollment and reboot, verify `sbctl list-enrolled-keys`, `sbctl status`,
`sbctl verify`, and `bootctl status`. The last should report Secure Boot enabled
in user mode. Hibernation may also be restricted by kernel lockdown once
Secure Boot is enabled; test suspend and hibernate before relying on them.

See the [Lanzaboote instructions](https://github.com/nix-community/lanzaboote/blob/master/docs/getting-started/enable-secure-boot.md).
