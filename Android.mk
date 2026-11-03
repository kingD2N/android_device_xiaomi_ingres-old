#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),ingres)

# modem.img (OS2.0.8.0.ULJCNXM) is stored in vendor/xiaomi/ingres/modem as
# parts below GitHub's 100 MB file limit. Join them back, verify the SHA1 and
# ship the result as a radio image (AB_OTA_PARTITIONS += modem in BoardConfig).
INGRES_MODEM_PARTS := $(sort $(wildcard vendor/xiaomi/ingres/modem/modem.img.part*))
INGRES_MODEM_SHA1 := c2a132566e51ccad4cc0d423d137459de3b6ce99

ifneq ($(INGRES_MODEM_PARTS),)
INSTALLED_RADIOIMAGE_TARGET += $(PRODUCT_OUT)/modem.img

$(PRODUCT_OUT)/modem.img: $(INGRES_MODEM_PARTS)
	$(hide) mkdir -p $(dir $@)
	$(hide) cat $^ > $@.tmp
	$(hide) echo "$(INGRES_MODEM_SHA1)  $@.tmp" | sha1sum -c --quiet - || \
	    (echo "modem.img: SHA1 mismatch" >&2; rm -f $@.tmp; exit 1)
	$(hide) mv $@.tmp $@
endif

endif
