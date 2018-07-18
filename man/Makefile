mandir := $(PREFIX)/share/man

PODS := clip-devutils.pod
SECTION := 7
DIR := man${SECTION}

PAGES := ${foreach file, ${basename ${PODS}}, ${DIR}/${file}.${SECTION}}

build: $(DIR) $(PAGES)

$(DIR):
	mkdir -p $(DIR)

${DIR}/%.${SECTION}:%.pod $(DIR) Makefile
	pod2man --utf8 -c="CLIP Development Tools" -s=${SECTION} -r="${PACKAGE}-${VERSION}" $< > $@

install:
	list='$(PAGES)'; for page in $$list; do \
		install -D $$page ${DESTDIR}${mandir}/$$page ;\
	done

uninstall:
	list='$(PAGES)'; for page in $$list; do \
		install -D $$page ${DESTDIR}${mandir}/$$page ;\
	done

clean:
	rm -f $(PAGES)
	-rmdir $(DIR)

