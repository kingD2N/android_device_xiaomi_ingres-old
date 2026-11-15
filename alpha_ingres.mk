#
# Copyright (C) 2025 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# /data tanpa enkripsi (decrypt). Wajib format data saat pertama kali flash.
# Build terenkripsi: DECRYPT=0 bash <script build>
TARGET_DECRYPTED_DATA ?= true

# Inherit from ingres device
$(call inherit-product, device/xiaomi/ingres/device.mk)

# AlphaDroid
# TARGET_BUILD_PACKAGE: 1 = vanilla, 2 = microG, 3 = GApps (diatur build-alpha.sh lewat GAPPS=)
TARGET_BUILD_PACKAGE ?= 3
TARGET_INCLUDE_PIXEL_LAUNCHER ?= true
ALPHA_MAINTAINER := D2N
ALPHA_BUILD_TYPE := Unofficial
TARGET_SCREEN_WIDTH := 1080
TARGET_SCREEN_HEIGHT := 2400
TARGET_BOOT_ANIMATION_RESOLUTION := 1080
TARGET_HAS_UDFPS := true

# Inherit from common AlphaDroid configuration
$(call inherit-product, vendor/alpha/config/common_full_phone.mk)

PRODUCT_NAME := alpha_ingres
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
