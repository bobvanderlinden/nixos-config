#!/usr/bin/env python3
import os
import subprocess
import json
from pathlib import PosixPath
import argparse

parser = argparse.ArgumentParser(
    prog="nixos-efi-gc",
    description="Remove unused EFI files",
)

parser.add_argument("--efi-mount",
                    required=True,
                    type=PosixPath,
                    help="The directory where the EFI partition is mounted"
                    )
parser.add_argument(
    "--dry-run",
    action="store_true",
    help="Avoid removing files, print what would be removed instead"
)
args = parser.parse_args()

dry_run = args.dry_run
efi_mount = args.efi_mount
linux = efi_mount / "EFI" / "Linux"
nixos = efi_mount / "EFI" / "nixos"
efi_files = set(efi_file for dir in [linux, nixos] for efi_file in dir.glob("*.efi"))

def exec(cmd):
    stdout, stderr = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, shell=True
    ).communicate()
    return stdout.decode("utf-8").strip()

def rm(file):
    if dry_run:
        print(f"Would remove {file}")
        return
    if os.system(f"sudo rm {file}") != 0:
        raise RuntimeError(f"Failed to remove file {file}")

boot_entries = json.loads(exec("bootctl list --json=short"))

def get_boot_entry_files(entry):
    if "path" in entry:
        yield PosixPath(entry["path"])
    if "linux" in entry:
        yield efi_mount / entry["linux"].removeprefix("/")

def efi_file_references(efi_file: PosixPath):
    return (
        efi_mount / efi_path.replace("\\", "/").removeprefix("/")
        for efi_path in exec(f"strings {efi_file.as_posix()} | grep .efi").split("\n")
        if efi_path.startswith("\\EFI\\")
        if efi_path.endswith(".efi")
    )

def efi_file_references_recursive(efi_file: PosixPath):
    pending = [efi_file]
    result = set()
    while pending:
        file = pending.pop(0)
        if file in result:
            continue
        result.add(file)
        pending.extend(efi_file_references(file))
    return result

boot_entry_files = [
    (entry, set((
        file
        for _file in get_boot_entry_files(entry)
        for file in efi_file_references_recursive(_file)
    )))
    for entry in boot_entries
]

referred_files = set(
    file
    for _, files in boot_entry_files
    for file in files
)

dangling_files = efi_files - referred_files

dangling_entries = [
    entry
    for entry, referred_files in boot_entry_files
    if not any(
        file in efi_files
        for file in referred_files
    )
]

if not dangling_files:
    print("No dangling files found")
    exit(0)

for file in dangling_files:
    rm(file)
