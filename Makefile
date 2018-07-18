# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.
PROGNAME := clip-devutils
PROGVER := 2.16.7
PKGNAME := ${PROGNAME}-${PROGVER}
PREFIX ?= /usr

export PROGVER PKGNAME PREFIX

SUBDIRS := bin man share

build:
	list='$(SUBDIRS)'; for dir in $$list; do \
		$(MAKE) -C $$dir build ;\
	done

clean:
	list='$(SUBDIRS)'; for dir in $$list; do \
		$(MAKE) -C $$dir clean ;\
	done
install:
	list='$(SUBDIRS)'; for dir in $$list; do \
		$(MAKE) -C $$dir install ;\
	done

uninstall:
	list='$(SUBDIRS)'; for dir in $$list; do \
		$(MAKE) -C $$dir uninstall ;\
	done
