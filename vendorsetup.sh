echo 'Starting to clone stuffs needed to build for ingres'

echo 'Cloning vendor ingres'
echo 'IMPORTANT WARNING: Generate the vendor yourself with OS2.0.4.0ULJCNMX (Redmi K50G Latest OS2 firmware. which is Chinese)'

echo 'Cloning sm8450-common'
git clone https://github.com/cupid-development/android_device_xiaomi_sm8450-common.git -b lineage-22.2 device/xiaomi/sm8450-common

echo 'Cloning vendor sm8450-common'
git clone https://github.com/TheMuppets/proprietary_vendor_xiaomi_sm8450-common.git -b lineage-22.2 vendor/xiaomi/sm8450-common

echo 'Cloning hardware xiaomi'
git clone https://github.com/LineageOS/android_hardware_xiaomi -b lineage-22.2 hardware/xiaomi

echo 'Cloning Kernel stuff'
git clone https://github.com/ingres-centre/android_kernel_xiaomi_sm8450.git -b lineage-22.2 kernel/xiaomi/sm8450
git clone https://github.com/cupid-development/android_kernel_xiaomi_sm8450-modules.git -b lineage-22.2 kernel/xiaomi/sm8450-modules
git clone https://github.com/ingres-centre/android_kernel_xiaomi_sm8450-devicetrees.git -b lineage-22.2 kernel/xiaomi/sm8450-devicetrees
