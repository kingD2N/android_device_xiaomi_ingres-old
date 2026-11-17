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

# Inherit from common lineage configuration
# ResurrectedRemix OS memakai vendor/rr (pengganti vendor/lineage); nama maintainer
# harus diisi sebelum vendor/rr dibaca.
RR_MAINTAINER := kingD2N

$(call inherit-product, vendor/rr/config/common_full_phone.mk)

# GApps (build-ingres.sh GAPPS=1): paket GApps Android 17 dari Evolution-X vendor_gms (cnb).
# Pixel Launcher dibuang oleh build-ingres.sh supaya layar utama tetap Trebuchet (Launcher3).
ifeq ($(WITH_GMS),true)
# vendor/gms (gms_full.mk + gms_setup.mk) sudah di-inherit oleh vendor/rr saat WITH_GMS=true
DONT_DEXPREOPT_PREBUILTS := true
# APK Google (GoogleDialer, GoogleContacts, dll.) mendaftarkan uses-library yang tidak
# dicatat di Android.mk vendor_gms; EvoX melonggarkan pemeriksaannya dengan cara yang sama.
RELAX_USES_LIBRARY_CHECK := true
PRODUCT_PRODUCT_PROPERTIES += \
    ro.opa.eligible_device=true \
    ro.setupwizard.rotation_locked=true \
    setupwizard.feature.baseline_setupwizard_enabled=true
endif

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
