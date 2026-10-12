set -euo pipefail

flake_source='@flakeSource@'
target_mount='/mnt'

usage() {
  cat <<'EOF'
Usage: install-nixos --host HOST --disko-config PATH --user USER [OPTIONS]

Install the selected flake host from a NixOS installer environment. HOST is the
nixosConfigurations attribute to install. DISKO-CONFIG is its source-relative
Disko template path (for example system/nac54003.nix). USER is the configured
normal user whose password will be set to the entered LUKS passphrase.

The Disko template must contain these literal placeholders, which are replaced
in a temporary source copy and never in the checkout:
  @INSTALLER_DISK@                selected stable whole-disk path
  @INSTALLER_SWAP_SIZE@           RAM plus 2 GiB, such as 34G
  @INSTALLER_LUKS_PASSWORD_FILE@  temporary file holding the LUKS passphrase

Options:
  --disk DEVICE          Whole non-removable disk to use. If omitted, selects
                         the only writable non-USB disk.
  --target-mount PATH    Target mount point (default: /mnt).
  --reuse-existing       Mount an existing NIXOS-LUKS layout instead of erasing.
  --help                 Show this help text.

The command shows the plan and requires ERASE or REUSE confirmation before
writing anything.
EOF
}

host=''
disko_config=''
user=''
disk=''
reuse_existing=false
while (( $# > 0 )); do
  case "$1" in
    --host)
      (( $# >= 2 )) || { echo '--host needs a flake host name' >&2; exit 2; }
      host="$2"
      shift 2
      ;;
    --disko-config)
      (( $# >= 2 )) || { echo '--disko-config needs a source-relative path' >&2; exit 2; }
      disko_config="$2"
      shift 2
      ;;
    --user)
      (( $# >= 2 )) || { echo '--user needs a configured user name' >&2; exit 2; }
      user="$2"
      shift 2
      ;;
    --disk)
      (( $# >= 2 )) || { echo '--disk needs a device path' >&2; exit 2; }
      disk="$2"
      shift 2
      ;;
    --target-mount)
      (( $# >= 2 )) || { echo '--target-mount needs a path' >&2; exit 2; }
      target_mount="$2"
      shift 2
      ;;
    --reuse-existing)
      reuse_existing=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$host" || -z "$disko_config" || -z "$user" ]]; then
  echo '--host, --disko-config, and --user are required.' >&2
  usage >&2
  exit 2
fi

if [[ ! "$host" =~ ^[[:alnum:]._-]+$ ]]; then
  echo "Invalid host name: $host" >&2
  exit 2
fi

if [[ "$disko_config" == /* || "$disko_config" == *".."* ]]; then
  echo "--disko-config must be a source-relative path without '..': $disko_config" >&2
  exit 2
fi

if (( EUID != 0 )); then
  echo 'Run this as root from the NixOS installer environment.' >&2
  exit 1
fi

if [[ ! -d /sys/firmware/efi ]]; then
  echo 'Boot the NixOS installer in UEFI mode. Secure Boot installation needs EFI variables.' >&2
  exit 1
fi

if mountpoint --quiet "$target_mount"; then
  echo "$target_mount is already mounted; unmount it before running the installer." >&2
  exit 1
fi

mapfile -t candidates < <(
  lsblk --json --paths --output PATH,TYPE,RM,RO,TRAN |
    jq --raw-output '
      .blockdevices[]
      | select(.type == "disk" and .rm == false and .ro == false and .tran != "usb")
      | .path'
)

if [[ -z "$disk" ]]; then
  case "${#candidates[@]}" in
    0)
      echo 'No writable non-USB disk was found. Pass --disk /dev/disk/by-id/...' >&2
      exit 1
      ;;
    1)
      disk="${candidates[0]}"
      ;;
    *)
      printf 'More than one writable non-USB disk was found:\n' >&2
      printf '  %s\n' "${candidates[@]}" >&2
      echo 'Pass --disk /dev/disk/by-id/... to choose one.' >&2
      exit 1
      ;;
  esac
fi

if [[ "$disk" != /* && -b "/dev/$disk" ]]; then
  disk="/dev/$disk"
fi

disk_type="$(lsblk --noheadings --nodeps --output TYPE "$disk" | tr --delete '[:space:]')"
if [[ ! -b "$disk" ]] || [[ "$disk_type" != 'disk' ]]; then
  echo "Not a whole disk: $disk" >&2
  exit 1
fi

disk_removable="$(lsblk --noheadings --nodeps --output RM "$disk" | tr --delete '[:space:]')"
disk_transport="$(lsblk --noheadings --nodeps --output TRAN "$disk" | tr --delete '[:space:]')"
if [[ "$disk_removable" == '1' ]] || [[ "$disk_transport" == 'usb' ]]; then
  echo "Refusing removable or USB disk: $disk" >&2
  exit 1
fi

canonical_disk="$(readlink --canonicalize "$disk")"
stable_disk="$canonical_disk"
while IFS= read -r by_id; do
  if [[ "$(readlink --canonicalize "$by_id")" == "$canonical_disk" ]]; then
    case "$(basename "$by_id")" in
      nvme-eui.*|wwn-*)
        stable_disk="$by_id"
        break
        ;;
      *)
        stable_disk="$by_id"
        ;;
    esac
  fi
done < <(find /dev/disk/by-id -maxdepth 1 -type l -print | sort)

memory_kib="$(awk '/MemTotal:/ { print $2 }' /proc/meminfo)"
memory_gib=$(( (memory_kib + 1048575) / 1048576 ))
# Hibernation needs a disk swap device at least as large as RAM. Add 2 GiB for
# metadata and pages which cannot be reclaimed before hibernating.
swap_gib=$(( memory_gib + 2 ))
root_minimum_gib=64
required_gib=$(( 1 + 2 + swap_gib + root_minimum_gib ))
disk_bytes="$(lsblk --bytes --noheadings --nodeps --output SIZE "$canonical_disk" | tr --delete '[:space:]')"
disk_gib=$(( disk_bytes / 1024 / 1024 / 1024 ))
if (( disk_gib < required_gib )); then
  printf 'The selected disk has %s GiB, but the layout needs at least %s GiB.\n' "$disk_gib" "$required_gib" >&2
  exit 1
fi

IFS=$'\t' read -r size model serial wwn < <(
  lsblk --json --output SIZE,MODEL,SERIAL,WWN "$canonical_disk" |
    jq --raw-output '.blockdevices[0] | [.size, .model, .serial, .wwn] | map(. // "unknown") | @tsv'
)

if [[ "$reuse_existing" == true ]]; then
  if ! lsblk --noheadings --output PARTLABEL "$canonical_disk" | grep --quiet --fixed-strings 'NIXOS-LUKS'; then
    echo "No NIXOS-LUKS partition was found on $canonical_disk; refusing --reuse-existing." >&2
    exit 1
  fi
  installation_action='reuse the existing encrypted layout'
  confirmation_word='REUSE'
else
  installation_action='erase the selected disk and create a new encrypted layout'
  confirmation_word='ERASE'
fi

cat <<EOF
The following installation plan will $installation_action.

Host:             $host
Disko template:   $disko_config
Configured user:  $user
Selected disk:    $canonical_disk
Persistent path:  $stable_disk
Size:             $size
Model:            $model
Serial:           $serial
WWN:              $wwn
Detected memory:  ${memory_gib} GiB
Disk swap:        ${swap_gib} GiB
Minimum root:     ${root_minimum_gib} GiB

Partition layout:
  1 GiB  NIXOS-ESP   EFI system partition, mounted at /boot/efi
  2 GiB  NIXOS-BOOT  ext4, mounted at /boot
  rest   NIXOS-LUKS  LUKS2 encrypted volume, opened as nixos
         nixos/swap  ${swap_gib} GiB encrypted LVM logical volume, resume device
         nixos/root  remaining encrypted ext4 filesystem, mounted at /

Secure Boot keys will be generated after installation. The first boot is
unsigned and enrolls the keys. Restart once enrollment has completed.
EOF

read -r -p "Type $confirmation_word to continue: " confirmation
if [[ "$confirmation" != "$confirmation_word" ]]; then
  echo 'Installation cancelled.'
  exit 0
fi

password_file="$(mktemp /tmp/nixos-luks-password.XXXXXXXX)"
work_directory="$(mktemp --directory /tmp/nixos-config.XXXXXXXX)"
cleanup() {
  umount --recursive "$target_mount" 2>/dev/null || true
  rm --force "$password_file"
  rm --recursive --force "$work_directory"
}
trap cleanup EXIT
chmod 600 "$password_file"
if [[ ! -d "$target_mount" ]]; then
  mkdir --mode=755 "$target_mount"
fi

read -r -s -p 'LUKS passphrase: ' luks_password
echo
read -r -s -p 'Repeat LUKS passphrase: ' luks_password_repeat
echo
if [[ "$luks_password" != "$luks_password_repeat" ]]; then
  echo 'Passphrases do not match.' >&2
  exit 1
fi
printf '%s' "$luks_password" > "$password_file"

cp --recursive --no-preserve=mode "$flake_source" "$work_directory/source"
disko_config_path="$work_directory/source/$disko_config"
if [[ ! -f "$disko_config_path" ]]; then
  echo "Disko template does not exist in the flake source: $disko_config" >&2
  exit 1
fi
for placeholder in @INSTALLER_SWAP_SIZE@ @INSTALLER_LUKS_PASSWORD_FILE@ @INSTALLER_DISK@; do
  if ! grep --quiet --fixed-strings "$placeholder" "$disko_config_path"; then
    echo "Disko template is missing required placeholder $placeholder: $disko_config" >&2
    exit 1
  fi
done
sed --in-place \
  --expression "s|@INSTALLER_SWAP_SIZE@|${swap_gib}G|" \
  --expression "s|@INSTALLER_LUKS_PASSWORD_FILE@|${password_file}|" \
  --expression "s|@INSTALLER_DISK@|${stable_disk}|" \
  "$disko_config_path"

if [[ "$reuse_existing" == true ]]; then
  disko_mode='mount'
else
  disko_mode='destroy,format,mount'
fi

echo 'Creating and mounting the encrypted target layout...'
disko \
  --mode "$disko_mode" \
  --root-mountpoint "$target_mount" \
  --flake "$work_directory/source#$host"

install --directory --mode=1777 "$target_mount/tmp"
echo 'Building the full NixOS configuration in the target disk store...'
nom build \
  --store "$target_mount" \
  --extra-experimental-features "nix-command flakes" \
  --out-link "$target_mount/tmp/system" \
  "$work_directory/source#nixosConfigurations.$host.config.system.build.toplevel"
system_path="$(readlink "$target_mount/tmp/system")"

echo 'Installing the built configuration and boot loader...'
nixos-install \
  --root "$target_mount" \
  --system "$system_path" \
  --no-root-password

printf '%s:%s\n' "$user" "$luks_password" | chpasswd --root "$target_mount"
unset luks_password luks_password_repeat
