#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.


if [ $# != 1 ]; then
    echo "add a pointer to a screenshot."
    echo "usage: $0 pfilename"
    echo " -pfilename: filename is the prefix of the filenames of both"
    echo "  the .jpg and the .txt file that respectively contain the"
    echo "  screen capture and the cursor position"
    exit 1
fi

if [ ! -e $1.jpg ]; then
    echo "file $1.jpg does not exists"
    exit 2
fi

if [ ! -e $1.txt ]; then
    echo "file $1.txt does not exists"
    exit 3
fi

GEOMETRY=$(sed 's/.*(\(.*\),\(.*\)).*/+\1+\2/' < "$1.txt")

composite -geometry ${GEOMETRY} pointer.png  "$1.jpg" "${1%%.jpg}-with-pointer.jpg"
