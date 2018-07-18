#!/bin/sh
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.
set -e

SCRIPT_DIR="/root/scripts"
REPO="/opt/build/svn"

MIRROR_VERSION=$($SCRIPT_DIR/mirror_version.sh ${REPO})
DIR="/root/mirrors/clip4-rm-dpkg-$MIRROR_VERSION"
    
MAIN_VERSION=$(echo $MIRROR_VERSION|cut -d "-" -f 1)
echo "version principale: $MAIN_VERSION"

CLIP_CORE="$MAIN_VERSION-r$(echo $MIRROR_VERSION|cut -d '-' -f 2|dd bs=1 skip=2 status=none)"
CLIP_APPS="$MAIN_VERSION-r$(echo $MIRROR_VERSION|cut -d '-' -f 3|dd bs=1 skip=2 status=none)"
RM_CORE="$MAIN_VERSION-r$(echo $MIRROR_VERSION|cut -d '-' -f 4|dd bs=1 skip=2 status=none)"
RM_APPS="$MAIN_VERSION-r$(echo $MIRROR_VERSION|cut -d '-' -f 5|dd bs=1 skip=2 status=none)"

echo "clip-core: $CLIP_CORE"
echo "clip-apps: $CLIP_APPS"
echo "rm-core: $RM_CORE"
echo "rm-apps: $RM_APPS"

umask 0022

DIST="clip"
/opt/clip-livecd/get-mirrors.sh -p "${REPO}/clip" -R "${DIR}" -d  \
"clip-core-conf_${CLIP_CORE}_i386.deb" -D "${DIST}" -c /opt/build/svn/clip-hermes
/opt/clip-livecd/get-mirrors.sh -p "${REPO}/clip" -R "${DIR}" -d  \
"clip-apps-conf_${CLIP_APPS}_i386.deb" -D "${DIST}" -c /opt/build/svn/clip-hermes

DIST="rm"
/opt/clip-livecd/get-mirrors.sh -p "${REPO}/rm" -R "${DIR}" -d  \
"rm-core-conf_${RM_CORE}_i386.deb" -D "${DIST}" -c /opt/build/svn/rm-hermes
/opt/clip-livecd/get-mirrors.sh -p "${REPO}/rm" -R "${DIR}" -d  \
"rm-apps-conf-h_${RM_APPS}_i386.deb" -C "rm-apps-conf" -D "${DIST}" -c \
/opt/build/svn/rm-hermes
/opt/clip-livecd/get-mirrors.sh -p "${REPO}/rm" -R "${DIR}" -d \
"rm-apps-conf-b_${RM_APPS}_i386.deb" -C "rm-apps-conf" -D "${DIST}" -c \
/opt/build/svn/rm-hermes

echo "mirror is (supposedely) ready in ${DIR}"
