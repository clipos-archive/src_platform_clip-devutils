# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.
PREFIX ?= /usr
EXES := \
	clip-bump \
	clip-changes \
	clip-checkconfig \
	clip-checkorphans \
	clip-checkpkg \
	clip-checksign \
	clip-cleanconfigs \
	clip-mkdistfile \
	clip-getdistfile \
	clip-patch-split \
	clip-prunepkgs \
	clip-sign \
	clip-update-mirror \
	img-geom-center \
	clip-cpdistfile \
	clip-vcs \
	clip-dpkg \
	clip-make \
	clip-installer-bootstrap \
	clip-sdk-bootstrap \
	clip-prepare-mirrors \
	gentoo-upkeep.sh \
	clip-compile-from-debname

build:

clean:

install:
	list='$(EXES)'; for exe in $$list; do \
		install -D $$exe ${DESTDIR}${PREFIX}/bin/$$exe ;\
	done

uninstall:
	list='$(EXES)'; for exe in $$list; do \
		rm -f ${DESTDIR}${PREFIX}/bin/$$exe ;\
	done

