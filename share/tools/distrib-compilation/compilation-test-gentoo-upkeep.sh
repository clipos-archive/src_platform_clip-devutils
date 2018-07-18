#!/bin/sh -e
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

# gentoo-upkeep.sh - CLIP SDK updater
# Copyright (C) 2012-2015 ANSSI
# Author: Mickaël Salaün <clipos@ssi.gouv.fr>
# All rights reserved

# Python upgrade procedure:
#emerge --update python
#emerge --oneshot portage
#equery belongs /usr/lib/python2.6 | awk '{print $1}' | while read atom; do
#	emerge --oneshot "${atom}" || emerge --unmerge "${atom}"
#done
#emerge --unmerge python:2.6

# Hack to fix circular dependencies (will be restore with the emerge --newuse)
# e.g. fix_circular "dev-libs/openssl" "1.0.1j" "-kerberos"
fix_circular() {
	local pkg_name="$1"
	local pkg_version_break="$2"
	local pkg_tmp_use="$3"
	local pkg_p1="${pkg_name}-$(equery --quiet list --format '$fullversion' "${pkg_name}" 2>/dev/null)"
	local pkg_p2="${pkg_name}-${pkg_version_break}"
	if qatom --quiet --compare "${pkg_p1}" "${pkg_p2}" | grep --quiet "^${pkg_p1} < ${pkg_p2}\$"; then
		USE="${pkg_tmp_use}" emerge --oneshot "${pkg_name}"
	fi
}

# Safe auto-update
if [ -z "${GENTOO_UPKEEP_UP_TO_DATE}" ]; then
	# Quickly guess if there is an update
	if equery --quiet list --format '$location' clip-dev/clip-devutils 2>/dev/null | grep --quiet '^I--$'; then
		emerge --oneshot --update clip-dev/clip-devutils
		# Safeguard
		GENTOO_UPKEEP_UP_TO_DATE=1 exec "$0"
	fi
fi

perl-cleaner --all
python-updater || true

# ticket 3189: Fix Kerberos circular dependency
fix_circular dev-libs/openssl 1.0.1j -kerberos

emerge --update --newuse --deep --keep-going=y @world
# emerge --depclean --deep --ask
emerge --depclean --deep
revdep-rebuild --ignore
lafilefixer --justfixit

# pour la recompilation on ne fait pas de etc-update
# etc-update
