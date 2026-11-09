#
# Copyright (C) 2025 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# /data tanpa enkripsi (decrypt). Wajib format data saat pertama kali flash.
# Build terenkripsi: DECRYPT=0 bash build-uwu.sh
TARGET_DECRYPTED_DATA ?= true

# Inherit from ingres device
$(call inherit-product, device/xiaomi/ingres/device.mk)

# Inherit some common uwuAOSP stuff.
UWU_DEVICE_TYPE := phone
UWU_SUPPORTS_TELEPHONY := true
UWU_MAINTAINER := kingD2N
$(call inherit-product, vendor/uwu/config/common.mk)

PRODUCT_NAME := uwu_ingres
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
