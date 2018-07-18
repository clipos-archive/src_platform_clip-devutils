#!/bin/sh
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

set -e

ACTION="$1"

usage() {
	echo "usage: $0 mount|umount [/dev/sdb1] [update]" >/dev/stderr
	exit 1
}

[ -n "${ACTION}" ] || usage

export DEVICE_DATA="${2:-/dev/sdb1}"
JAIL="${3:-update}"

. /lib/clip/usb_storage.sub

export DEVTYPE="usb"
export DEVPATH="/block/$(basename -- "${DEVICE_DATA}" | head -c 3)"
export CLEARTEXT_MOUNT="yes"
export CURRENT_USER_TYPE="privuser"
export CURRENT_STR_LEVEL="clip"
export NOTIFY="/bin/true"

case "${ACTION}" in
	mount)
		get_jail_by_level "${JAIL}"
		map_device
		mount_device
		;;
	umount)
		get_hotplug_device_del
		get_jail_by_level "${JAIL}"
		umount_device "nomsg"
		dec_usb_status
		;;
	*)
		usage
		;;
esac
