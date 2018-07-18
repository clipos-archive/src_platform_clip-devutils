#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.
die () {
	echo "$*" >&2
	exit 1
}

get_version () {
	local conf_name="$1"
	conf_deb_path=$(find "${mirror}/" -type f -name "${conf_name}_*_*.deb" 2>/dev/null)
	ret=$?
	[[ $ret == 0 && "${conf_deb_path}" != "" ]] || return 1
# only retains the higher version of the package
	max=""
	for pkg in ${conf_deb_path}; do
		version=$(dpkg-deb -W "${pkg}"|awk '{print $2}')
		if [ -z "$max" ] || dpkg --compare-versions "${max}" lt "${version}" ; then
			max="${version}";
		fi
	done

	conf_ver_ver="${max%-*}"
	conf_ver_rev="${max#*-r}"

	echo "$conf_ver_ver $conf_ver_rev"
}

ver () {
	echo $* | cut -d' ' -f1
}

rev () {
	echo $* | cut -d' ' -f2
}

while (( "$#" )); do
case $1 in
"-v")
VIRTUAL=yes
;;
"gtw"|"GTW")
GTW="yes"
;;
*)
mirror=$1
;;
esac
shift
done
mirror=${mirror:-clip-clt-dpkg}

cc="$(get_version "clip-core-conf")" || die "clip-core-conf missing"
ca="$(get_version "clip-apps-conf")" || die "clip-apps-conf missing"
if [ ! -n "$GTW" ]; then
    rc="$(get_version "rm-core-conf")" || die "rm-core-conf missing"
    rab="$(get_version "rm-apps-conf-b")" || die "rm-apps-conf-b missing"
    rah="$(get_version "rm-apps-conf-h")" || die "rm-apps-conf-h missing"
else
    rc=0
    rab=0
    rah=0
fi

virtual=$(( $(rev $cc) + $(rev $ca) + $(rev $rc) + $(rev $rah) ))

version=$(ver $cc)
if [ ! -n "$GTW" ]; then
    for verrev in "$ca" "$rc" "$rab" "$rah"; do
            [ "$(ver $verrev)" = "$version" ] || die "Inconsistent versions"
    done
else
    [ "$(ver $ca)" = "$version" ] || die "Inconsistent versions"
fi

[ "$(rev $rab)" = "$(rev $rah)" ] || die "Inconsistent rm-apps-conf-{h,b} versions"
if [ -n "$VIRTUAL" ]; then
	echo "$(ver $cc)-v$virtual"
else
    if [ ! -n "$GTW" ]; then
	echo "$(ver $cc)-cc$(rev $cc)-ca$(rev $ca)-rc$(rev $rc)-ra$(rev $rah)"
    else
	echo "$(ver $cc)-cc$(rev $cc)-ca$(rev $ca)"
    fi
fi
