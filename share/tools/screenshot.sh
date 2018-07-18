#!/bin/sh
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

# TODO: install imagemagick

# /etc/inittab
# kb::kbrequest:/mounts/clip-screenshot
# init q

DIR_JAIL="/var/run/screenshots"
DIR_CORE="/vservers/rm_h/user_priv${DIR_JAIL}"
PPPATH="./pointerposition"

export DISPLAY=:0.0
export XAUTHORITY="/var/run/authdir/slim.auth"
export PATH=${PATH}:/usr/local/bin
export LD_LIBRARY_PATH="/usr/local/lib"

umask 0022
[[ -d "${DIR_CORE}" ]] || mkdir -p -- "${DIR_CORE}"

VT=$(fgconsole)
if [ ${VT} != "7" ]; then
    chvt 7 # go on the X VT
fi

DATE=$(date '+%Y%m%d-%H%M%S-%N')

if [ -x ${PPPATH} ]; then
    ${PPPATH} > "${DIR_CORE}/${DATE}.txt"
fi

import -screen -window root "${DIR_CORE}/${DATE}.jpg"

chvt ${VT}

#import -screen
#import -display "${DISPLAY}" -window root "${DIR_CORE}/$(date +%F_%T).eps"
