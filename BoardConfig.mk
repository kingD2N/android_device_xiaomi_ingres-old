#
# Copyright (C) 2022-2023 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from xiaomi sm8450-common
include device/xiaomi/sm8450-common/BoardConfigCommon.mk

# Inherit from the proprietary version
include vendor/xiaomi/ingres/BoardConfigVendor.mk

# Inherit from proprietary files for miuicamera
# -include device/xiaomi/miuicamera-ingres/BoardConfig.mk

BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_INCORRECT_PARTITION_IMAGES := true

DEVICE_PATH := device/xiaomi/ingres
# Switch to OSS Kernel!
# - this should be disabled because why not? we're not using it anyways.
#KERNEL_PATH := device/xiaomi/ingres-kernel

# Camera - Miui
# TARGET_CAMERA_PACKAGE_NAME := com.android.camera


# And these go kaboom cuz we usin' OSS Kernel atm. IT IS AT TESTING STAGE AND NOT SUITABLE FOR DAILY USAGE.
# - we have only screen n base dts and not audio/camera dts. [TMP]
# Kernel prebuilt
# BOARD_USES_DT := true
# BOARD_PREBUILT_DTBIMAGE_DIR := $(KERNEL_PATH)/dtbs
# BOARD_PREBUILT_DTBOIMAGE := $(KERNEL_PATH)/dtbs/dtbo.img

# TARGET_FORCE_PREBUILT_KERNEL := true
# TARGET_KERNEL_SOURCE := $(KERNEL_PATH)/kernel-headers
# TARGET_NO_KERNEL_OVERRIDE := true
# TARGET_PREBUILT_KERNEL := $(KERNEL_PATH)/kernel

# PRODUCT_COPY_FILES += $(TARGET_PREBUILT_KERNEL):kernel

# Kernel modules
# DLKM_MODULES_PATH := $(KERNEL_PATH)/vendor_dlkm
# RAMDISK_MODULES_PATH := $(KERNEL_PATH)/vendor_ramdisk

# BOARD_VENDOR_KERNEL_MODULES := $(wildcard $(DLKM_MODULES_PATH)/*.ko)
# BOARD_VENDOR_KERNEL_MODULES_LOAD := $(patsubst %,$(DLKM_MODULES_PATH)/%,$(shell cat $(DLKM_MODULES_PATH)/modules.load))
# BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(DLKM_MODULES_PATH)/modules.blocklist
# BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(wildcard $(RAMDISK_MODULES_PATH)/*.ko)
# BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(patsubst %,$(RAMDISK_MODULES_PATH)/%,$(shell cat $(RAMDISK_MODULES_PATH)/modules.load))
# BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD  := $(patsubst %,$(RAMDISK_MODULES_PATH)/%,$(shell cat $(RAMDISK_MODULES_PATH)/modules.load.recovery))
# BOARD_VENDOR_RAMDISK_KERNEL_MODULES_BLOCKLIST_FILE := $(RAMDISK_MODULES_PATH)/modules.blocklist

# PRODUCT_COPY_FILES += \
#     $(call find-copy-subdir-files,*,$(KERNEL_PATH)/vendor_dlkm/,$(TARGET_COPY_OUT_VENDOR_DLKM)/lib/modules) \
#     $(call find-copy-subdir-files,*,$(KERNEL_PATH)/vendor_ramdisk/,$(TARGET_COPY_OUT_VENDOR_RAMDISK)/lib/modules)

# Properties
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/properties/system.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/properties/vendor.prop

# Screen density
TARGET_SCREEN_DENSITY := 395

# Permissive
# BOARD_BOOTCONFIG += androidboot.selinux=permissive

# Capacity mAh
BOARD_BATTERY_CAPACITY := 4700
