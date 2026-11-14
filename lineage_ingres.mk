#
# Copyright (C) 2025 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# /data tanpa enkripsi (decrypt). Wajib format data saat pertama kali flash.
# Build terenkripsi: DECRYPT=0 bash build-infinity.sh
TARGET_DECRYPTED_DATA ?= true

# Inherit from ingres device
$(call inherit-product, device/xiaomi/ingres/device.mk)

# Project Infinity X
INFINITY_MAINTAINER := kingD2N
# Infinity X 4.2: produk berawalan lineage_; nama device untuk nama zip & ro.infinity.device
INFINITY_BUILD ?= ingres
# sensor sidik jari di tombol power (bukan di layar)
TARGET_HAS_UDFPS := false
# GApps: build-infinity.sh mengisi WITH_GAPPS (GAPPS=0 -> vanilla)
WITH_GAPPS ?= true

# Inherit from common Infinity X configuration
$(call inherit-product, vendor/infinity/config/common_full_phone.mk)

# Info "Tentang ponsel" Infinity X ada di properties/system.prop
# (ro.product.marketname, ro.infinity.soc, ro.infinity.camera)

PRODUCT_NAME := lineage_ingres
PRODUCT_DEVICE := ingres
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_BRAND := Redmi
PRODUCT_MODEL := 21121210G

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="ingres-user 14 UKQ1.240624.001 OS2.0.8.0.ULJCNXM release-keys" \
    BuildFingerprint=Redmi/ingres/ingres:14/UKQ1.240624.001/OS2.0.8.0.ULJCNXM:user/release-keys \
    DeviceProduct=ingres \
    SystemName=ingres

PRODUCT_GMS_CLIENTID_BASE := android-xiaomi
