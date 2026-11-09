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

## Build uwuAOSP 17 (Android 17, branch `uwu-17.0`)

uwuAOSP ([uwuAOSP/platform_manifests](https://github.com/uwuAOSP/platform_manifests), branch `uwu-17.0`)
berbasis AOSP `android-17.0.0_r1` dan memakai repo hardware LineageOS `lineage-24.0`, jadi tree ingres
LineageOS 24 dipakai langsung. Bedanya: produk `uwu_ingres` di `uwu_ingres.mk` (mewarisi
`vendor/uwu/config/common.mk` dengan `UWU_DEVICE_TYPE := phone`, `UWU_SUPPORTS_TELEPHONY := true`),
lunch `uwu_ingres-cp2a-user`, paket dibuat dengan `m otapackage`, dan GApps Pixel selalu ikut.

| Bagian | Repo | Branch |
|---|---|---|
| Device // ingres | [kingD2N/android_device_xiaomi_ingres-old](https://github.com/kingD2N/android_device_xiaomi_ingres-old/tree/uwu-17.0) | uwu-17.0 |
| Device // common | [kingD2N/Ingres_device_xiaomi_sm8450-common](https://github.com/kingD2N/Ingres_device_xiaomi_sm8450-common) | lineage-24.0 |
| Vendor // ingres | kingD2N/proprietary_vendor_xiaomi_ingres | lineage-24.0 |
| Vendor // common | [TheMuppets/proprietary_vendor_xiaomi_sm8450-common](https://github.com/TheMuppets/proprietary_vendor_xiaomi_sm8450-common) | lineage-24.0 |
| Kernel | [kingD2N/android_kernel_xiaomi_sm8450](https://github.com/kingD2N/android_kernel_xiaomi_sm8450) | lineage-24.0 |
| Kernel module | [LineageOS/android_kernel_xiaomi_sm8450-modules](https://github.com/LineageOS/android_kernel_xiaomi_sm8450-modules) | lineage-24.0 |
| Kernel device tree | [kingD2N/android_kernel_xiaomi_sm8450-devicetrees](https://github.com/kingD2N/android_kernel_xiaomi_sm8450-devicetrees) | lineage-24.0 |

Cara paling mudah (skrip otomatis, jalan di byobu):

```bash
curl -fsSL -o ~/build-uwu.sh https://raw.githubusercontent.com/kingD2N/android_device_xiaomi_ingres-old/uwu-17.0/build-uwu.sh
bash ~/build-uwu.sh          # sync + build (varian user)
bash ~/build-uwu.sh status   # cek progres
```

| Perintah | Fungsi |
|---|---|
| `bash ~/build-uwu.sh` | sync + build |
| `bash ~/build-uwu.sh sync` / `build` | hanya sync / hanya build |
| `bash ~/build-uwu.sh status` | lihat progres |
| `bash ~/build-uwu.sh upload` | upload ulang hasil ke GoFile |
| `bash ~/build-uwu.sh bersih [folder]` | hapus source ROM lain (default `~/lunaris`) |
| `bash ~/build-uwu.sh reset-ingres` | hapus repo ingres/xiaomi lalu sync ulang |
| `bash ~/build-uwu.sh clean` | hapus `out/` dan `~/hasil-uwu` |

Varian default **user**; debug: `VARIANT=userdebug bash ~/build-uwu.sh`. Hasil di `~/hasil-uwu`
dan otomatis diupload ke GoFile (matikan dengan `GOFILE=0`).

Manual:

```bash
repo init --repo-url=https://github.com/UwUniverse/git-repo.git --repo-branch=main --no-repo-verify \
  -u https://github.com/uwuAOSP/platform_manifests.git -b uwu-17.0 --git-lfs --no-clone-bundle
mkdir -p .repo/local_manifests
curl -L -o .repo/local_manifests/uwu.xml \
  https://raw.githubusercontent.com/kingD2N/android_device_xiaomi_ingres-old/uwu-17.0/local_manifests/uwu.xml
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
source build/envsetup.sh
lunch uwu_ingres-cp2a-user
m otapackage
```

## Decrypt

`/data` **tanpa enkripsi** secara default (`TARGET_DECRYPTED_DATA := true`): wajib Format Data saat pertama
flash. Build terenkripsi: `DECRYPT=0 bash ~/build-uwu.sh`.

## Firmware

ROM ini **tidak** membawa firmware (sama seperti ROM AOSP/LineageOS pada umumnya): zip hanya
berisi partisi ROM (boot, dtbo, vendor_boot, recovery, system, system_ext, product, vendor,
vendor_dlkm, odm, vbmeta). Blob vendor diambil dari HyperOS **OS2.0.8.0.ULJCNXM**, jadi
pastikan firmware di HP sudah OS2.0.8.0 (atau versi HyperOS 2 terbaru) sebelum memasang ROM.

Image firmware OS2.0.8.0 tersedia di release
[ingres-firmware-OS2.0.8.0.ULJCNXM](https://github.com/kingD2N/firmware_Update/releases/tag/ingres-firmware-OS2.0.8.0.ULJCNXM)
untuk di-flash manual lewat fastboot (`fastboot flash <partisi>_a <partisi>.img` dan `_b`).

## Paket tambahan

Setiap build otomatis membawa: **GameKeys**, **LED** (app Leds + lampu status notifikasi/baterai),
**Dolby Lunaris**, **JamesDSP**, dan **MIUI Camera**. Sumbernya ada di local manifest
(`vendor/ingres/addons` = [kingD2N/LED_ingres_for_Notifikasi_system](https://github.com/kingD2N/LED_ingres_for_Notifikasi_system/tree/addons) branch `addons`).
Matikan satu paket di `device.mk` sebelum baris addons, misal `INGRES_ADDONS_MIUICAMERA := false`.
