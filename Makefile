# 
# arm-none-eabi-gcc toolchain
# build script for STM32 development
#
# Copyright (C) 2013 by Tokoro <tokoro10g@tokor.org>
# http://wiki.tokor.org
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# 

DOWNLOAD_DIR:=$(CURDIR)/download
WGET_OPTIONS=-nc -P $(DOWNLOAD_DIR)
TARGET:=h8300-elf
TOP:=$(CURDIR)
PREFIX:=$(CURDIR)/install
ADDON_TOOLS_DIR=$(CURDIR)/addontools

export PATH:=$(PREFIX)/bin:$(PATH)

INSTALL_DIR=/opt/cross/h8300-elf-x-tools

BINUTILS_VER=2.16.1
GCC_VER=4.4.6
NEWLIB_VER=1.20.0
GMP_VER=5.1.2
MPFR_VER=3.1.2
MPC_VER=1.0.1

BINUTILS_SRC="binutils-$(BINUTILS_VER)"
GCC_SRC="gcc-$(GCC_VER)"
NEWLIB_SRC="newlib-$(NEWLIB_VER)"
GMP_SRC="gmp-$(GMP_VER)"
MPFR_SRC="mpfr-$(MPFR_VER)"
MPC_SRC="mpc-$(MPC_VER)"

ABI_MODE='ABI=32'
CC='gcc -m32'

all: get-packages extract patch build

get-packages:
	@echo
	@echo Getting packages from remote...
	wget $(WGET_OPTIONS) -i packagelist
	@echo 

extract:
	@echo 
	@echo Extracting tarball...
	$(foreach file,$(wildcard $(DOWNLOAD_DIR)/*.tar.gz),tar zxf $(file);)
	$(foreach file,$(wildcard $(DOWNLOAD_DIR)/*.tar.bz2),tar jxf $(file);)
	@echo 

patch:
	@echo 
	@echo Patching files...
	patch -p1 -d $(BINUTILS_SRC) < patches/$(BINUTILS_SRC).patch
	patch -p1 -d $(GCC_SRC) < patches/$(GCC_SRC).patch
	@echo 

build: build-gmp build-mpfr build-mpc build-binutils build-gcc-1 build-newlib build-gcc-2 strip

build-gmp:
	@echo 
	@echo Building gmp...
	mkdir -p gmp-build;\
	cd gmp-build;\
	../$(GMP_SRC)/configure $(ABI_MODE) --prefix=$(ADDON_TOOLS_DIR) --disable-shared;\
	make;\
	make install
	-@rm $(ADDON_TOOLS_DIR)/lib/*.dylib 2>/dev/null || true
	@echo 

build-mpfr:
	@echo 
	@echo Building mpfr...
	mkdir -p mpfr-build;\
	cd mpfr-build;\
	../$(MPFR_SRC)/configure $(ABI_MODE) --prefix=$(ADDON_TOOLS_DIR) --disable-shared --with-gmp-build=$(ADDON_TOOLS_DIR)/../gmp-build;\
	make;\
	make install
	@echo 

build-mpc:
	@echo 
	@echo Building mpc...
	mkdir -p mpc-build;\
	cd mpc-build;\
	CPPFLAGS=-I$(ADDON_TOOLS_DIR)/include LDFLAGS=-L$(ADDON_TOOLS_DIR)/lib \
	../$(MPC_SRC)/configure $(ABI_MODE) --prefix=$(ADDON_TOOLS_DIR) --disable-shared;\
	make;\
	make install
	@echo 

build-binutils:
	@echo 
	@echo Building binutils...
	mkdir -p binutils-build;\
	cd binutils-build;\
	CFLAGS="-I$(ADDON_TOOLS_DIR)/include" \
	LDFLAGS="-L$(ADDON_TOOLS_DIR)/lib" \
	../$(BINUTILS_SRC)/configure \
		--target=$(TARGET) \
		--prefix=$(PREFIX) \
		--disable-shared \
		--disable-nls \
		--disable-threads \
		--enable-multilib;\
	make;\
	make install
	@echo 

build-gcc-1:
	@echo 
	@echo Building gcc 1st-pass...
	mkdir -p gcc-build;\
	cd gcc-build;\
	../$(GCC_SRC)/configure \
		--target=$(TARGET) \
		--prefix=$(PREFIX) \
		--disable-shared \
		--disable-nls \
		--disable-threads \
		--disable-libada \
		--disable-libssp \
		--disable-libstdcxx-pch \
		--disable-libmudflap \
		--disable-libgomp -v \
		--enable-languages=c \
		--enable-long-long \
		--enable-multilib \
		--enable-obsolete \
		--with-newlib \
		--with-headers=../$(NEWLIB_SRC)/newlib/libc/include \
		--with-mpc=$(ADDON_TOOLS_DIR) \
		--with-mpfr=$(ADDON_TOOLS_DIR) \
		--with-gmp=$(ADDON_TOOLS_DIR);\
	mkdir -p libiberty libcpp fixincludes;\
	make all-gcc;\
	make install-gcc
	@echo 

build-newlib:
	@echo 
	@echo Building newlib...
	mkdir -p newlib-build;\
	cd newlib-build;\
	mkdir -p etc;\
	../$(NEWLIB_SRC)/configure \
		--target=$(TARGET) \
		--prefix=$(PREFIX) \
		--disable-newlib-supplied-syscalls \
		--enable-multilib;\
	make;\
	make install
	@echo 

build-gcc-2:
	@echo 
	@echo Building gcc 2nd-pass...
	cd gcc-build;\
	export LIBRARY_PATH=/usr/lib/i386-linux-gnu:$(LIBRARY_PATH);\
	make;\
	make install
strip:
	-$(foreach file,$(PREFIX)/bin/*,strip $(file))
	-$(foreach file,$(PREFIX)/$(TARGET)/bin/*,strip $(file))
	-$(foreach file,$(PREFIX)/libexec/gcc/$(TARGET)/$(GCC_VER)/*,strip $(file))
	find $(PREFIX) -name "crt0.o" -exec rm {} \;
	find $(PREFIX) -name "*.la" -exec rm {} \;

.PHONY: install
install:
	mkdir -p $(INSTALL_DIR)
	cp -R install/* $(INSTALL_DIR)

distclean:
	rm -rf *-build install addontools
