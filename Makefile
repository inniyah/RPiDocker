#!/usr/bin/env -S make -f

IMG_ARMHF=2022-04-04-raspios-bullseye-armhf-lite
IMG_ARM64=2022-04-04-raspios-bullseye-arm64-lite

MNT_SYSTEM_DIR=root
MNT_BOOT_DIR=root/boot

LOSETUP=sudo losetup

all: rootfs/$(IMG_ARMHF).tgz rootfs/$(IMG_ARM64).tgz

master/2022-04-04-raspios-bullseye-armhf-lite.img.xz:
	@mkdir -vp '$(shell dirname '$@')'
	cd '$(shell dirname '$@')' && \
		wget 'https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2022-04-07/$(shell basename '$@')'
	cd '$(shell dirname '$@')' && \
		wget 'https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2022-04-07/$(shell basename '$@').sha256'
	cd '$(shell dirname '$@')' && \
		sha256sum --check '$(shell basename '$@').sha256'

master/2022-04-04-raspios-bullseye-arm64-lite.img.xz:
	@mkdir -vp '$(shell dirname '$@')'
	cd '$(shell dirname '$@')' && \
		wget 'https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-04-07/$(shell basename '$@')'
	cd '$(shell dirname '$@')' && \
		wget 'https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-04-07/$(shell basename '$@').sha256'
	cd '$(shell dirname '$@')' && \
		sha256sum --check '$(shell basename '$@').sha256'

image/%.img: master/%.img.xz
	@mkdir -vp '$(shell dirname '$@')'
	cd '$(shell dirname '$<')' && sha256sum --check '$(shell basename '$<').sha256'
	xz --decompress --keep --stdout --verbose --threads=0 '$<' > '$@'
	touch '$@'

mnt/%: image/%.img
	@mkdir -vp '$@'
	@-sudo umount -l '$@/boot' 2>/dev/null || true
	@-sudo umount -l '$@' 2>/dev/null || true
	@test ! -e '$@/boot' || rmdir '$@/boot'
	@test ! -e '$@' || rmdir '$@'
	mkdir -vp '$@/boot'
	export LOSETUP_DEV="$$( $(LOSETUP) --show -f -P '$<' )" && \
		sudo mount "$${LOSETUP_DEV}p2" '$@' && \
		sudo mount "$${LOSETUP_DEV}p1" '$@/boot'
	#~ mkdir -vp cache/apt/archives
	#~ sudo mount --bind 'cache/apt/' '$@/var/cache/apt/'

rootfs/%.tgz: mnt/%
	@mkdir -vp '$(shell dirname '$@')'

	cd '$<' && sudo tar cvfz '../../$@' . && sudo chown "$(shell id -u):$(shell id -g)" '../../$@'

	#~ @-sudo umount -l '$</var/cache/apt/' 2>/dev/null || true
	@-sudo umount -l '$</boot' 2>/dev/null || true
	@-sudo umount -l '$<' 2>/dev/null || true
	@test ! -e '$</boot' || rmdir '$</boot'
	@test ! -e '$<' || rmdir '$<'
	sudo losetup -l | grep `realpath 'image/$*.img'` | awk -F'[ \t\n]' '{print $$1}' | while read LOSETUP_DEV ; do \
		test -z "$${LOSETUP_DEV}" || $(LOSETUP) -d "$${LOSETUP_DEV}" ; \
		done

	sync
	touch '$@'
