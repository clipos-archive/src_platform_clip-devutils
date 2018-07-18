#!/bin/sh
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

DISK_FILE="/home/user/VirtualBox VMs/gtw0/usb0.vdi"
DISK_DEV="/dev/nbd0"
DISK_MOUNT="/mnt/vm-usb0"

do_start() {
        qemu-nbd -c "${DISK_DEV}" "${DISK_FILE}" &
        mount "${DISK_DEV}" -o "offset=$((8*512))" "${DISK_MOUNT}"
}

do_stop() {
        umount "${DISK_MOUNT}" || return 1
        qemu-nbd -d "${DISK_DEV}"
}

usage() {
        echo "usage: $0 -s|-q" >&2
        exit 0
}

[[ $# -eq 0 ]] && usage
while getopts sq opt; do
        case "${opt}" in
                s) do_start;;
                q) do_stop;;
                *) usage;;
        esac
done
