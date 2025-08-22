echo 'Starting to clone stuffs needed to build for ingres'

echo 'Cloning vendor ingres'
echo 'IMPORTANT WARNING: Generate the vendor yourself with OS2.0.4.0ULJCNMX (Redmi K50G Latest OS2 firmware. which is Chinese)'

echo 'Cloning sm8450-common'
git clone https://github.com/LineageOS/android_device_xiaomi_sm8450-common.git -b lineage-22.2 device/xiaomi/sm8450-common

echo 'Cloning vendor sm8450-common'
git clone https://github.com/TheMuppets/proprietary_vendor_xiaomi_sm8450-common.git -b lineage-22.2 vendor/xiaomi/sm8450-common

echo 'Cloning hardware xiaomi'
git clone https://github.com/LineageOS/android_hardware_xiaomi -b lineage-22.2 hardware/xiaomi

echo 'Cloning Kernel stuff'
git clone https://github.com/ingres-centre/android_kernel_xiaomi_sm8450.git -b lineage-22.2 kernel/xiaomi/sm8450
git clone https://github.com/LineageOS/android_kernel_xiaomi_sm8450-modules.git -b lineage-22.2 kernel/xiaomi/sm8450-modules
git clone https://github.com/ingres-centre/android_kernel_xiaomi_sm8450-devicetrees.git -b lineage-22.2 kernel/xiaomi/sm8450-devicetrees

if [ "$1" == "--force" ]; then
	echo 'WARNING: You specified "--force" argument!'
	echo 'Repositories related to hardware will be force redownloaded!'
	rm -rf hardware/qcom-caf/sm8450/audio/agm
	rm -rf hardware/qcom-caf/sm8450/audio/primary-hal
	rm -rf hardware/qcom-caf/sm8450/audio/pal
	rm -rf hardware/qcom-caf/sm8450/audio/graphservices
fi

echo 'Cloning hardware stuff'
git clone https://github.com/Ingres-Centre/android_vendor_qcom_opensource_agm -b lineage-22.2-caf-sm8450 hardware/qcom-caf/sm8450/audio/agm
git clone https://github.com/Ingres-Centre/android_hardware_qcom_audio-ar -b lineage-22.2-caf-sm8450 hardware/qcom-caf/sm8450/audio/primary-hal
git clone https://github.com/Ingres-Centre/android_vendor_qcom_opensource_arpal-lx -b lineage-22.2-caf-sm8450 hardware/qcom-caf/sm8450/audio/pal
git clone https://github.com/Ingres-Centre/android_vendor_qcom_opensource_audioreach-graphservices -b lineage-22.2-caf-sm8450 hardware/qcom-caf/sm8450/audio/graphservices

echo 'Looking for patch targets...'
PATCH_TARGETS="$(find device/xiaomi/ingres/patches/ | grep '.patch$' | awk '{ gsub(/([a-zA-Z0-9-_]+\.patch)/, ""); } NF && !seen[$0]++' | sed 's/device\/xiaomi\/ingres\/patches\///')"

if [ "$1" == "--force" ]; then
	echo "WARNING: The targets to which the patches will be applied will have a git reset performed."
fi

for TARGET in $PATCH_TARGETS; do
	BACK_PATH="$(echo $TARGET | sed -E 's/[a-zA-Z0-9_-]+/../g')"
	echo Applying patches to $TARGET

	cd "$TARGET"

	if [ "$1" == "--force" ]; then
		echo "Performing git reset..."
		git fetch origin 1&>/dev/null
		git reset --hard origin 1&>/dev/null
		git clean -fd 1&>/dev/null
	fi

	git am --3way "$BACK_PATH/device/xiaomi/ingres/patches/$TARGET"/*.patch | grep 'Applying: '
	cd "$BACK_PATH"
done
