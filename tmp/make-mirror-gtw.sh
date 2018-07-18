#!/bin/sh
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.
set -e

SCRIPT_DIR="/root/scripts"
REPO="/opt/build/svn-gtw"

MIRROR_VERSION=$($SCRIPT_DIR/mirror_version.sh gtw ${REPO})
DIR="/root/mirrors/clip4-gtw-dpkg-$MIRROR_VERSION"
    
MAIN_VERSION=$(echo $MIRROR_VERSION|cut -d "-" -f 1)

CLIP_CORE="$MAIN_VERSION-r$(echo $MIRROR_VERSION|cut -d '-' -f 2|dd bs=1 skip=2 status=none)"
CLIP_APPS="$MAIN_VERSION-r$(echo $MIRROR_VERSION|cut -d '-' -f 3|dd bs=1 skip=2 status=none)"

umask 0022

DIST="clip"
/opt/clip-livecd/get-mirrors.sh -p "${REPO}/clip" -R "${DIR}" -d  \
"clip-core-conf_${CLIP_CORE}_i386.deb" -D "${DIST}" -c /opt/build/svn-gtw/clip-hermes
/opt/clip-livecd/get-mirrors.sh -p "${REPO}/clip" -R "${DIR}" -d  \
"clip-apps-conf_${CLIP_APPS}_i386.deb" -D "${DIST}" -c /opt/build/svn-gtw/clip-hermes

echo "mirror is (supposedely) ready in ${DIR}"
