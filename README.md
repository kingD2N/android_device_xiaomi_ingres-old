Copyright (C) 2025 The LineageOS Project

Device configuration for Redmi K50 Gaming/POCO F4 GT
=========================================

The Redmi K50 Gaming/POCO F4 GT (codenamed _"ingres"_) is a high-end gaming smartphone from Redmi/POCO.

It was globally released in Feb 2022.

## Device specifications

Basic   | Spec Sheet
-------:|:-------------------------
Platform | Snapdragon® 8 Gen 1 (SM8450)
RAM & Storage | 8GB/128GB, 12GB/256GB (LPDDR5 RAM, UFS 3.1 storage)
Shipped Android Version | 12
Battery | Non-removable, 4700 mAh
Display | 6.67" OLED, 120Hz, 2400x1080 (~395 ppi)
Rear camera | 64MP IMX686 wide angle, 8MP ultra wide-angle, 2MP macro
Front camera | 20MP IMX596 in-display

## Device picture

![POCO F4 GT](https://i01.appmifile.com/webfile/globalimg/products/pc/poco-f4-gt/specs01.png "POCO F4 GT in all colours")

## Build LineageOS 24.0 (Android 17)

| Bagian | Repo | Branch |
|---|---|---|
| Device // ingres | [kingD2N/android_device_xiaomi_ingres-old](https://github.com/kingD2N/android_device_xiaomi_ingres-old) | lineage-24.0 |
| Device // common | [kingD2N/Ingres_device_xiaomi_sm8450-common](https://github.com/kingD2N/Ingres_device_xiaomi_sm8450-common) | lineage-24.0 |
| Vendor // ingres | kingD2N/proprietary_vendor_xiaomi_ingres | lineage-24.0 |
| Vendor // common | [TheMuppets/proprietary_vendor_xiaomi_sm8450-common](https://github.com/TheMuppets/proprietary_vendor_xiaomi_sm8450-common) | lineage-24.0 |
| Kernel | [kingD2N/android_kernel_xiaomi_sm8450](https://github.com/kingD2N/android_kernel_xiaomi_sm8450) | lineage-24.0 |
| Kernel module | [LineageOS/android_kernel_xiaomi_sm8450-modules](https://github.com/LineageOS/android_kernel_xiaomi_sm8450-modules) | lineage-24.0 |
| Kernel device tree | [kingD2N/android_kernel_xiaomi_sm8450-devicetrees](https://github.com/kingD2N/android_kernel_xiaomi_sm8450-devicetrees) | lineage-24.0 |

Cara paling mudah (skrip otomatis, jalan di byobu):

```bash
curl -LO https://raw.githubusercontent.com/kingD2N/android_device_xiaomi_ingres-old/lineage-24.0/build-ingres.sh
bash build-ingres.sh          # sync + build
bash build-ingres.sh status   # cek progres
```

Manual:

```bash
repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --git-lfs --no-clone-bundle
mkdir -p .repo/local_manifests
curl -L -o .repo/local_manifests/ingres.xml \
  https://raw.githubusercontent.com/kingD2N/android_device_xiaomi_ingres-old/lineage-24.0/local_manifests/ingres.xml
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
source build/envsetup.sh
breakfast ingres
m bacon
```

## Firmware

ROM ini **tidak** membawa firmware (sama seperti ROM AOSP/LineageOS pada umumnya): zip hanya
berisi partisi ROM (boot, dtbo, vendor_boot, recovery, system, system_ext, product, vendor,
vendor_dlkm, odm, vbmeta). Blob vendor diambil dari HyperOS **OS2.0.8.0.ULJCNXM**, jadi
pastikan firmware di HP sudah OS2.0.8.0 (atau versi HyperOS 2 terbaru) sebelum memasang ROM.

Image firmware OS2.0.8.0 tersedia di release
[ingres-firmware-OS2.0.8.0.ULJCNXM](https://github.com/kingD2N/firmware_Update/releases/tag/ingres-firmware-OS2.0.8.0.ULJCNXM)
untuk di-flash manual lewat fastboot (`fastboot flash <partisi>_a <partisi>.img` dan `_b`).
