#
# Copyright (C) 2022-2023 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from xiaomi sm8450-common
include device/xiaomi/sm8450-common/BoardConfigCommon.mk

# Inherit from the proprietary version
include vendor/xiaomi/ingres/BoardConfigVendor.mk

# Vendor gamekey additions (if present)
-include vendor/xiaomi/gamekey/BoardConfigVendor.mk

# Inherit from proprietary files for miuicamera (if it exists)
-include device/xiaomi/miuicamera-ingres/BoardConfig.mk

# Architecture
TARGET_ARCH_VARIANT := armv8-2a-dotprod

TARGET_2ND_ARCH :=
TARGET_2ND_ARCH_VARIANT :=
TARGET_2ND_CPU_ABI :=
TARGET_2ND_CPU_ABI2 :=
TARGET_2ND_CPU_VARIANT :=
TARGET_2ND_CPU_VARIANT_RUNTIME :=

# Audio
AUDIO_FEATURE_ENABLED_DLKM := true
AUDIO_FEATURE_ENABLED_DTS_EAGLE := false
AUDIO_FEATURE_ENABLED_GEF_SUPPORT := true
AUDIO_FEATURE_ENABLED_HW_ACCELERATED_EFFECTS := false
AUDIO_FEATURE_ENABLED_INSTANCE_ID := true
AUDIO_FEATURE_ENABLED_PAL_HIDL := true
AUDIO_FEATURE_ENABLED_PROXY_DEVICE := true

TARGET_USES_QCOM_MM_AUDIO := true

# Build
DEVICE_PATH := device/xiaomi/ingres
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_INCORRECT_PARTITION_IMAGES := true
TARGET_PROVIDES_AUDIO_HAL ?= true

# Capacity mAh
BOARD_BATTERY_CAPACITY := 4700

# Kernel
device_vendor_dlkm_exclusive_modules := \
    xm_gamekeys.ko

BOARD_VENDOR_KERNEL_MODULES_LOAD += $(device_vendor_dlkm_exclusive_modules)
TARGET_KERNEL_EXT_MODULES += gamekeys

# Init
$(call soong_config_set,libinit,vendor_init_lib,//$(DEVICE_PATH):init_xiaomi_ingres)
TARGET_RECOVERY_DEVICE_MODULES ?= init_xiaomi_ingres

# Properties
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/properties/system.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/properties/vendor.prop

# Screen density
TARGET_SCREEN_DENSITY := 395
