# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.
PREFIX ?= /usr
FILES:= $(wildcard tools/pointerposition/Makefile tools/pointerposition/*.c tools/*.txt tools/*.png tools/*.sh tools/*.patch tools/vizmounts/* tools/clip-virt tools/clip-virt-network.xml lxc/*.conf lxc/*.txt lxc/*.sh pubkeys/*.asc)
sharedir := share/clip-devutils

.PHONY: build clean install uninstall

build:

clean:

install:
	list='$(FILES)'; for shfile in $$list; do \
		install -m 0644 -D $$shfile ${DESTDIR}${PREFIX}/$(sharedir)/$$shfile ;\
	done

uninstall:
	list='$(FILES)'; for shfile in $$list; do \
		rm -f ${DESTDIR}${PREFIX}/$(sharedir)/$$shfile ;\
	done
	rmdir ${DESTDIR}${PREFIX}/$(sharedir){/{tools,lxc},}
