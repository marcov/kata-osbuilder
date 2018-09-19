#
# Copyright (c) 2017 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#
MK_DIR :=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

DISTRO ?= centos
DISTRO_ROOTFS := $(PWD)/$(DISTRO)_rootfs
DISTRO_ROOTFS_MARKER := .$(shell basename $(DISTRO_ROOTFS)).done
IMAGE := kata-containers.img
INITRD_IMAGE := kata-containers-initrd.img
IMG_SIZE=500
AGENT_INIT ?= no

ROOTFS_BUILDER := "$(MK_DIR)/rootfs-builder/rootfs.sh"

VERSION_FILE := ./VERSION
VERSION := $(shell grep -v ^\# $(VERSION_FILE))
COMMIT_NO := $(shell git rev-parse HEAD 2> /dev/null || true)
COMMIT := $(if $(shell git status --porcelain --untracked-files=no),${COMMIT_NO}-dirty,${COMMIT_NO})
VERSION_COMMIT := $(if $(COMMIT),$(VERSION)-$(COMMIT),$(VERSION))

#
ALL_DISTROS := $(shell $(ROOTFS_BUILDER) -l | tr "\n" " ")
ALL_ROOTFS_MARKERS := $(foreach distro,$(ALL_DISTROS),$(ROOTFS_BUILD_DEST)/.$(distro)_rootfs.done)
ALL_ROOTFS_DIRS := $(foreach distro,$(ALL_DISTROS),$(ROOTFS_BUILD_DEST)/$(distro)_rootfs)
ALL_IMAGES := $(foreach distro,$(ALL_DISTROS),$(IMAGES_BUILD_DEST)/kata-containers-image-$(distro).img)
ALL_INITRDS := $(foreach distro,$(ALL_DISTROS),$(IMAGES_BUILD_DEST)/kata-containers-initrd-$(distro).img)
#
ALL_ROOTFS_TGTS := $(foreach distro,$(ALL_DISTROS),rootfs-$(distro))
ALL_IMAGE_TGTS := $(foreach distro,$(ALL_DISTROS),image-$(distro))
ALL_INITRD_TGTS := $(foreach distro,$(ALL_DISTROS),initrd-$(distro))

################################################################################

.PHONY: rootfs-all
rootfs-all: $(ALL_ROOTFS_MARKERS)

.PHONY: image-all
image-all: $(ALL_IMAGES)

.PHONY: initrd-all
initrd-all: $(ALL_INITRDS)

.PHONY: list-distros
list-distros:
	@$(ROOTFS_BUILDER) -l

.PHONY: all
all: image initrd

.PHONY: rootfs
rootfs: $(DISTRO_ROOTFS_MARKER)

$(DISTRO_ROOTFS_MARKER):
	@echo Creating rootfs based on "$(DISTRO)"
	"$(MK_DIR)/rootfs-builder/rootfs.sh" -o $(VERSION_COMMIT) -r $(DISTRO_ROOTFS) $(DISTRO)
	touch $@

.PHONY: image
image: $(IMAGE)

$(IMAGE): rootfs
	@echo Creating image based on "$(DISTRO_ROOTFS)"
	"$(MK_DIR)/image-builder/image_builder.sh" -s "$(IMG_SIZE)" "$(DISTRO_ROOTFS)"

.PHONY: initrd
initrd: $(INITRD_IMAGE)

$(INITRD_IMAGE): rootfs
	@echo Creating initrd image based on "$(DISTRO_ROOTFS)"
	"$(MK_DIR)/initrd-builder/initrd_builder.sh" "$(DISTRO_ROOTFS)"

.PHONY: test
test:
	"$(MK_DIR)/tests/test_images.sh" "$(DISTRO)"

.PHONY: test-image-only
test-image-only:
	"$(MK_DIR)/tests/test_images.sh" --test-images-only "$(DISTRO)"

.PHONY: test-initrd-only
test-initrd-only:
	"$(MK_DIR)/tests/test_images.sh" --test-initrds-only "$(DISTRO)"

.PHONY: clean
clean:
	rm -rf $(DISTRO_ROOTFS_MARKER) $(DISTRO_ROOTFS) $(IMAGE) $(INITRD_IMAGE)

.PHONY: cleanall
cleanall:
	rm -rf $(ALL_ROOTFS_MARKERS) $(ALL_ROOTFS_DIRS) $(DISTRO_IMAGE) $(DISTRO_INITRD) $(ALL_IMAGES) $(ALL_INITRDS)
