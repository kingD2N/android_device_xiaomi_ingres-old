echo 'Starting to clone stuffs needed to build for ingres'

echo 'Cloning vendor ingres'
#git clone https://gitlab.com/vherawidatama/vendor_xiaomi_ingres.git -b 14 vendor/xiaomi/ingres
echo 'LMAO Extract the vendor yourself im lazy to deal with LFS shits'

echo 'Cloning sm8450-common'
git clone https://github.com/Ingres-Centre/android_device_xiaomi_sm8450-common.git -b lineage-22.2 device/xiaomi/sm8450-common

echo 'Cloning vendor sm8450-common'
git clone https://github.com/Ingres-Centre/android_vendor_xiaomi_sm8450-common.git -b lineage-22.2 vendor/xiaomi/sm8450-common

echo 'Cloning hardware xiaomi'
git clone https://github.com/LineageOS/hardware_xiaomi.git -b lineage-22.2 hardware/xiaomi

echo 'Cloning ingres-kernel'
# git clone https://github.com/Ingres-Centre/android_device_xiaomi_ingres-kernel.git -b smgreborn device/xiaomi/ingres-kernel

