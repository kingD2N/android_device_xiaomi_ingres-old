#
# Copyright (C) 2022-2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from ingres device
$(call inherit-product, device/xiaomi/ingres/device.mk)

# Inherit from common lineage configuration
$(call inherit-product, vendor/voltage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_ingres
PRODUCT_DEVICE := ingres
PRODUCT_MANUFACTURER := POCO
PRODUCT_BRAND := POCO
PRODUCT_MODEL := 21121210G

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="ingres-user 12 SKQ1.230401.001 OS2.0.5.0.ULJCNXM release-keys" \
    BuildFingerprint=Redmi/ingres/ingres:12/SKQ1.230401.001/OS2.0.5.0.ULJCNXM:user/release-keys \
    DeviceProduct=ingres \
    SystemName=ingres_global

PRODUCT_GMS_CLIENTID_BASE := android-xiaomi

# Private signature (include if exists)
-include vendor/lineage-priv/keys/keys.mk

# VoltageOS flags.
TARGET_FACE_UNLOCK_SUPPORTED := true
VOLTAGE_BUILD_TYPE := UNOFFICIAL

# Voltage OS CPU Flag
VOLTAGE_CPU_SMALL_CORES := 0,1,2,3
VOLTAGE_CPU_BIG_CORES := 4,5,6,7

# CPU Sets configuration
VOLTAGE_CPU_BG := 0-3
VOLTAGE_CPU_FG := 0-7
VOLTAGE_CPU_LIMIT_BG := 0-2
VOLTAGE_CPU_UNLIMIT_UI := 0-7
VOLTAGE_CPU_LIMIT_UI := 0-3
VOLTAGE_CPU_DISPLAY := 4-7
VOLTAGE_CPU_AUDIO := 0-4

