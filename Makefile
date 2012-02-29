# CONFINE firmware generator (http://confine-project.eu)
#
#    Copyright (C) 2011 Universitat Politecnica de Barcelona (UPC)
#
#    Thiss program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

OWRT_GIT = git@github.com:confine-project/openwrt.git
OWRT_PKG_GIT = git@github.com:confine-project/packages.git
TIMESTAMP = $(shell date +%d%m%y_%H%M)
BUILD_DIR = openwrt
FILES_DIR = files
PACKAGE_DIR = packages
OWRT_PKG_DIR = $(PACKAGE_DIR)/openwrt
OWRT_FEEDS = feeds.conf
CONFIG_DIR = configs
MY_CONFIGS = my_configs
DOWNLOAD_DIR = dl
CONFIG = $(BUILD_DIR)/.config
KCONFIG = $(BUILD_DIR)/target/linux/x86/config-*
IMAGES = images
IMAGE = openwrt-x86-generic-combined
J ?= 1
V ?= 0
MAKE_SRC = -j$(J) V=$(V)

define prepare_workspace
	[ ! -d $(DOWNLOAD_DIR) ] && mkdir -p $(DOWNLOAD_DIR) || true
	cat $(OWRT_FEEDS) | sed -e "s|PATH|`pwd`/$(PACKAGE_DIR)|" > $(BUILD_DIR)/feeds.conf
	rm -f $(BUILD_DIR)/dl || true
	ln -s `readlink -f $(DOWNLOAD_DIR)` $(BUILD_DIR)/dl
	rm -rf $(BUILD_DIR)/files || true
	ln -s ../$(FILES_DIR) $(BUILD_DIR)/files
endef

define update_feeds
	@echo "Updating feed $(1)"
	$(BUILD_DIR)/$(1)/scripts/feeds update -a
	$(BUILD_DIR)/$(1)/scripts/feeds install -a
endef

define copy_config
	cat $(CONFIG_DIR)/owrt_config $(CONFIG_DIR)/kernel_config |sort -u > $(CONFIG)
	cd $(BUILD_DIR) && make defconfig
endef

define copy_files
	mkdir -p $(BUILD_DIR)/files
	cp -rf $(FILES_DIR)/* $(BUILD_DIR)/files/
endef

define menuconfig_owrt
	make -C $(BUILD_DIR) menuconfig
	mkdir -p $(MY_CONFIGS)
	cd $(BUILD_DIR) && scripts/diffconfig.sh | sort -u > $(MY_CONFIGS)/owrt_config
	@echo "New OpenWRT configuration file saved on $(MY_CONFIGS)/owrt_config"
endef

define kmenuconfig_owrt
	make -C $(BUILD_DIR) kernel_menuconfig
	mkdir -p $(MY_CONFIGS)
	cat $(KCONFIG) | grep CONFIG | sort -u | sed s/^CONFIG/CONFIG_KERNEL/g > $(MY_CONFIGS)/kernel_config
	@echo "New Kernel configuration file saved on $(MY_CONFIGS)/kernel_config"
endef

define build_src
	make -C $(BUILD_DIR) $(MAKE_SRC)
endef

define post_build
	mkdir -p $(IMAGES)
	[ -f $(BUILD_DIR)/bin/x86/$(IMAGE)-squashfs.img.gz ] && gunzip $(BUILD_DIR)/bin/x86/$(IMAGE).gz || true
	cp -f $(BUILD_DIR)/bin/x86/$(IMAGE)-squashfs.img $(IMAGES)/CONFINE-owrt-$(TIMESTAMP).img
	cp -f $(BUILD_DIR)/bin/x86/$(IMAGE)-ext4.vdi $(IMAGES)/CONFINE-owrt-$(TIMESTAMP).vdi
	@echo 
	@echo "CONFINE firmware compiled, you can find output files in $(IMAGES)/ directory"
endef


all: prepare sync
	$(call build_src)
	$(call post_build)

prepare: .prepared

.prepared:
	git submodule init
	git submodule update
	(cd $(BUILD_DIR) && git checkout master)
	(cd $(OWRT_PKG_DIR) && git checkout master)
	@touch .prepared

sync: prepare
	$(call prepare_workspace)
	$(call update_feeds)
	$(call copy_files)
	$(call copy_config)

menuconfig: prepare
	$(call menuconfig_owrt)

kernel_menuconfig: prepare
	$(call kmenuconfig_owrt)

clean:
	make -C $(BUILD_DIR) clean

dirclean:
	make -C $(BUILD_DIR) dirclean

distclean:
	make -C $(BUILD_DIR) distclean
	$(call copy_files)
	$(call copy_config)

help:
	@cat README
