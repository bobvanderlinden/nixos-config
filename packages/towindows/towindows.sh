#!/usr/bin/env bash
set -x
set -o errexit
bootnum=$(efibootmgr | grep "Windows Boot Manager" | cut -c 5-8)
efibootmgr --bootnext $bootnum
reboot
