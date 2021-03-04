#!/usr/bin/env bash
set -x
set -o errexit
whoami
groups
env
echo "$0"
bootnum=$(efibootmgr | grep "Windows Boot Manager" | cut -c 5-8)
efibootmgr --bootnext $bootnum
reboot
