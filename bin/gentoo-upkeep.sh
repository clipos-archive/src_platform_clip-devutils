#!/bin/sh -e
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

# gentoo-upkeep.sh - CLIP SDK updater
# Copyright (C) 2012-2016 ANSSI
# Author: Mickaël Salaün <clipos@ssi.gouv.fr>
# All rights reserved

source /etc/clip-build.conf

EMERGE_QUIET="--quiet=y"
REVDEP_QUIET="--quiet"

CLIP_FETCH_SDK="${CLIP_BASE}/portage-overlay-clip/clip-layout/baselayout-sdk/files/clip-fetch"
CLIP_FETCH="/usr/lib/portage/bin/clip-fetch"

# Python upgrade procedure:
#emerge --update python
#emerge --oneshot portage
#equery belongs /usr/lib/python2.6 | awk '{print $1}' | while read atom; do
#	emerge --oneshot "${atom}" || emerge --unmerge "${atom}"
#done
#emerge --unmerge python:2.6

# hack to fix clip-fetch not found error
# it is useful when updating an old sdk image
# note: as clip-fetch is *very* useful, this should be called first
fix_missing_clip_fetch () {
  # copy clip-fetch from the sdk in order to be able to install gcc
  if [[ ! -f "${CLIP_FETCH}" ]]; then
    if [[ -f "${CLIP_FETCH_SDK}" ]]; then
	    cp "${CLIP_FETCH_SDK}" "${CLIP_FETCH}"
      # install gcc which is a dependency of baselayout-sdk
	    emerge --quiet=y --oneshot =sys-devel/gcc-4.7.4
      # remove clip-fetch and install baselayout-sdk to retrieve it in a clean way
	    rm ${CLIP_FETCH}
	    emerge --quiet=y --oneshot clip-layout/baselayout-sdk
    fi
  fi
}

# Hack to fix circular dependencies (will be restore with the emerge --newuse)
# e.g. fix_circular "dev-libs/openssl" "1.0.1j" "-kerberos"
fix_circular() {
	local pkg_name="$1"
	local pkg_version_break="$2"
	local pkg_tmp_use="$3"
	local pkg_p1="${pkg_name}-$(equery --quiet list --format '$fullversion' "${pkg_name}" 2>/dev/null)"
	local pkg_p2="${pkg_name}-${pkg_version_break}"
	if qatom --quiet --compare "${pkg_p1}" "${pkg_p2}" | grep --quiet "^${pkg_p1} < ${pkg_p2}\$"; then
		USE="${pkg_tmp_use}" emerge ${EMERGE_QUIET} --oneshot "${pkg_name}"
	fi
}

check_baselayout_breaking_change() {
	emerge --update baselayout-sdk

	local baselayout_pkg=clip-layout/baselayout-sdk
	local baselayout_current="${baselayout_pkg}-$(equery --quiet list --format '$fullversion' "${baselayout_pkg}" 2>/dev/null)"
	local baselayout_break="${baselayout_pkg}-1.3.0"

	if ! qatom --quiet --compare "${baselayout_current}" "${baselayout_break}" | grep --quiet "^${baselayout_current} < ${baselayout_break}\$" ; then
		if ! grep -q DISTDIR /etc/make.conf ; then

			echo
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
			echo
			echo
			echo
			echo "L'organisation des distfiles dans le SDK a changé."
			echo
			echo "Il est mainteant nécessaire de mettre à jour votre "
			echo "/etc/make.conf pour qu'il définisse la variable"
			echo "DISTDIR pointant sur un dossier temporaire dédié"
			echo "(par exemple DISTDIR=/tmp/distfiles-link)."
			echo
			echo
			echo "Appuyer sur ENTREE pour procéder à cette mise à jour"
			echo
			echo
			echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
			echo

			read

			etc-update

			if ! grep -q DISTDIR /etc/make.conf ; then
				echo
				echo "Vous n'avez pas mis à jour votre /etc/make.conf"
				echo
				echo "Je ne peux pas continuer !!"
				echo
				exit 1
			fi

		fi
	fi
}

# Special case to handle pam/shadow/pambase update:
# * 'pam' won't compile if '/etc/pam.d/login' isn't updated first
# * /etc/pam.d/login is removed from 'shadow' and provided by 'pambase'
check_pam_shadow_update() {
	if grep -q 'pam_console' '/etc/pam.d/login' ; then
		local pkg="sys-libs/pam"
		local pkg_break="${pkg}-1.1.8-r4"
		local pkg_current="${pkg}-$(equery --quiet list --format '$fullversion' "${pkg}" 2>/dev/null)"
		if qatom --quiet --compare "${pkg_current}" "${pkg_break}" | grep --quiet "^${pkg_current} < ${pkg_break}\$" ; then
			emerge --oneshot sys-apps/shadow sys-auth/pambase
		fi
		echo
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		echo
		echo "La mise à jour du fichier /etc/pam.d/login est nécessaire"
		echo "pour poursuivre."
		echo
		echo "Appuyer sur ENTREE pour continuer."
		echo
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		echo

		read

		etc-update

		if grep -q 'pam_console' '/etc/pam.d/login' ; then
			echo
			echo "/etc/pam.d/login n'est pas encore à jour."
			echo
			exit 1
		fi
	fi
}

fix_missing_clip_fetch

# Safe auto-update
if [ -z "${GENTOO_UPKEEP_UP_TO_DATE}" ]; then
	# Quickly guess if there is an update
	if equery --quiet list --format '$location' clip-dev/clip-devutils 2>/dev/null | grep --quiet '^I--$'; then
		emerge ${EMERGE_QUIET} --oneshot --update clip-dev/clip-devutils
		# Safeguard
		GENTOO_UPKEEP_UP_TO_DATE=1 exec "$0"
	fi
fi

check_baselayout_breaking_change

check_pam_shadow_update

perl-cleaner --all
python-updater || true

# ticket 3189: Fix Kerberos circular dependency
fix_circular dev-libs/openssl 1.0.1j -kerberos

emerge ${EMERGE_QUIET} --update --newuse --deep --keep-going=y @world
emerge ${EMERGE_QUIET} --depclean --deep --ask
revdep-rebuild ${REVDEP_QUIET} --ignore -- ${EMERGE_QUIET}
lafilefixer --justfixit
etc-update
