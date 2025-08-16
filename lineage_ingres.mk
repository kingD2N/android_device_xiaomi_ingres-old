#
# Copyright (C) 2022-2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from ingres device
$(call inherit-product, device/xiaomi/ingres/device.mk)

# Inherit from common lineage configuration
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_ingres
PRODUCT_DEVICE := ingres
PRODUCT_MANUFACTURER := POCO
PRODUCT_BRAND := POCO
PRODUCT_MODEL := 21121210G

PRODUCT_SYSTEM_NAME := ingres_global
PRODUCT_SYSTEM_DEVICE := ingres

#PRODUCT_BUILD_PROP_OVERRIDES += \
#    PRIVATE_BUILD_DESC="ingres_global-user 14 UKQ1.230917.001 V816.0.7.0.ULBMIXM release-keys" \
#    TARGET_DEVICE=$(PRODUCT_SYSTEM_DEVICE) \
#    TARGET_PRODUCT=$(PRODUCT_SYSTEM_NAME)

BUILD_FINGERPRINT := Xiaomi/ingres_global/ingres:14/UKQ1.230917.001/V816.0.5.0.ULJMIXM:user/release-keys

PRODUCT_GMS_CLIENTID_BASE := android-xiaomi
