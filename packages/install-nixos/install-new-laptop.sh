set -euo pipefail

flake_source='@flakeSource@'
host='new-laptop'
bootstrap_host='new-laptop-bootstrap'

usage() {
  cat <<'EOF'
Usage: install-new-laptop [--disk DEVICE]

Selects the only writable, non-USB disk when possible. Use --disk to choose a
specific whole-disk device. The command always shows its plan and requires an
explicit confirmation before it writes anything.
EOF
}

disk=''
while (( $# > 0 )); do
  case "$1" in
    --disk)
      (( $# >= 2 )) || { echo '--disk needs a device path' >&2; exit 2; }
      disk="$2"
      shift 2
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

if (( EUID != 0 )); then
  echo 'Run this as root from the NixOS installer environment.' >&2
  exit 1
fi

if [[ ! -d /sys/firmware/efi ]]; then
  echo 'Boot the NixOS installer in UEFI mode. Secure Boot installation needs EFI variables.' >&2
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

cat <<EOF
The following installation plan will erase the selected disk.

Final host:       $host
Bootstrap host:   $bootstrap_host
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

read -r -p 'Type ERASE to partition, encrypt, and install: ' confirmation
if [[ "$confirmation" != 'ERASE' ]]; then
  echo 'Installation cancelled.'
  exit 0
fi

password_file="$(mktemp /tmp/nixos-luks-password.XXXXXXXX)"
work_directory="$(mktemp --directory /tmp/nixos-config.XXXXXXXX)"
target_mount="$work_directory/target"
cleanup() {
  umount --recursive "$target_mount" 2>/dev/null || true
  rm --force "$password_file"
  rm --recursive --force "$work_directory"
}
trap cleanup EXIT
chmod 600 "$password_file"
mkdir "$target_mount"

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
sed --in-place \
  --expression "s|SWAP_SIZE|${swap_gib}G|" \
  --expression "s|/tmp/nixos-luks-password|${password_file}|" \
  "$work_directory/source/systems/new-laptop.nix"

echo 'Partitioning, formatting, and installing the NixOS configuration...'
# disko-install detects nom-build and uses it for its single system build.
disko-install \
  --flake "$work_directory/source#$bootstrap_host" \
  --disk main "$stable_disk" \
  --write-efi-boot-entries

# disko-install cleans up its mounts before returning, but leaves the encrypted
# volume open. Set the initial account password directly in the target root.
mount /dev/nixos/root "$target_mount"
printf '%s:%s\n' 'bob.vanderlinden' "$luks_password" | chpasswd --root "$target_mount"
unset luks_password luks_password_repeat
