#/usr/bin/make
SHELL=/bin/bash

# Define PREFIX only if needed
ifndef PREFIX
  PREFIX=/usr/local
endif

# Define DESTDIR only if needed
ifndef DESTDIR
   DESTDIR=
endif

KAMELEON_DIR=$(PREFIX)/share/kameleon
MANDIR=$(PREFIX)/share/man
BINDIR=$(PREFIX)/bin
SBINDIR=$(PREFIX)/sbin
DOCDIR=$(PREFIX)/share/doc/kameleon
VARLIBDIR=/var/lib
DIST=

build: build-man

build-man:
	rd2 -rrd/rd2man-lib.rb kameleon.rb > kameleon.1

install-engine:
	install -d -m 0755 $(DESTDIR)$(BINDIR)
	install -d -m 0755 $(DESTDIR)$(KAMELEON_DIR)
	install -m 755 kameleon.rb $(DESTDIR)$(KAMELEON_DIR)
	echo "#! /bin/bash" > $(DESTDIR)$(BINDIR)/kameleon
	echo "RUBYOPT=rubygems $(KAMELEON_DIR)/kameleon.rb \$$*" >> $(DESTDIR)$(BINDIR)/kameleon
	-chmod 755 $(DESTDIR)$(BINDIR)/kameleon

install-data:
	install -d -m 0755 $(DESTDIR)$(KAMELEON_DIR)
	install -d -m 0755 $(DESTDIR)$(KAMELEON_DIR)/steps
	install -d -m 0755 $(DESTDIR)$(KAMELEON_DIR)/recipes
	for dir in steps/*; do [ $$dir != "steps/old" ] && cp -r $$dir $(DESTDIR)$(KAMELEON_DIR)/steps || true; done
	for file in recipes/*; do [ $$file != "recipes/old" ] && install -m 0644 $$file $(DESTDIR)$(KAMELEON_DIR)/recipes || true; done
	install -d -m 755 $(DESTDIR)$(VARLIBDIR)/kameleon/steps
	install -d -m 755 $(DESTDIR)$(VARLIBDIR)/kameleon/recipes

install-doc:
	install -d -m 0755 $(DESTDIR)$(DOCDIR)
	install Documentation.rst $(DESTDIR)$(DOCDIR)
	install COPYING $(DESTDIR)$(DOCDIR)
	install AUTHORS $(DESTDIR)$(DOCDIR)

install-man:
	install -d -m 0755 $(DESTDIR)$(MANDIR)/man1
	install kameleon.1 $(DESTDIR)$(MANDIR)/man1

install: install-engine install-data install-doc install-man

uninstall: 
	rm -rf $(DESTDIR)$(KAMELEON_DIR)
	rm -f $(DESTDIR)$(BINDIR)/kameleon
	rm -rf $(DESTDIR)$(DOCDIR)

clean:
	rm -f kameleon.1

dist-snapshot:
	$(MAKE) -e dist DIST="kameleon-$$(cat VERSION)+snapshot.$$(git log --format=oneline|wc -l).$$(git log -1 --format=%h)"

dist-release:
	$(MAKE) -e dist DIST="kameleon-$$(cat VERSION)"

dist: dist-clean
ifdef DIST
	mkdir -p build/$(DIST)
	cp -af -t build/$(DIST) \
	    AUTHORS COPYING Documentation.rst \
	    kameleon.rb Makefile recipes steps redist VERSION
	tar czf ../$(DIST).tar.gz -C build $(DIST)
	rm -rf build
	echo "../$(DIST).tar.gz"
else
	echo "You need to specify the 'DIST'. Use dist-snapshot or dist-release targets"
endif

dist-clean:
	rm -rf build
