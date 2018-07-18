#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

i=1

for prefix in $(ls -1 $* | sed s/\.jpg\$//); do  ./add-pointer.sh $prefix; echo "$i done"; let i=$i+1; done
