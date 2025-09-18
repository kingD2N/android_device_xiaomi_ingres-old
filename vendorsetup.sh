echo 'Starting to clone stuffs needed to build for ingres'

if [ -e ".lock-setup" ]; then
    echo "You have lock-file to prevent local changes overwrite! Exitting..."
    exit 0
fi

CWD="$(realpath .)"

if [ "$1" == "--force" ]; then
    echo "WARNING: You are specified '--force' argument!"
	echo "WARNING: The targets to which the patches will be applied will have a git reset performed."
    FORCE=1
else
	FORCE=0
fi

echo "Self-updating..."
{
    cd device/xiaomi/ingres

    OLD_SUM="$(sha1sum ./vendorsetup.sh)"
    git pull
	if [ "$FORCE" -eq 1 ]; then
		git reset --hard origin
	fi
    NEW_SUM="$(sha1sum ./vendorsetup.sh)"

    cd "$CWD"

    if [[ "$OLD_SUM" != "$NEW_SUM" ]]; then
        echo "device/xiaomi/ingres/vendorsetup.sh was updated! Rerunning..."

        if [ "$FORCE" -eq "1" ]; then 
            bash device/xiaomi/ingres/vendorsetup.sh --force
        else
            bash device/xiaomi/ingres/vendorsetup.sh
        fi

        exit 0
    fi
}

error() {
    echo "$@" 1>&2;
}

clone-repo() {
    REPO_OWNER="$1"
    REPO_NAME="$2"
    BRANCH=$3
    OUT=$4

    if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
        error "Not all arguments provided!"
        error "Usage: clone-repo OWNER REPO_NAME BRANCH OUT_DIR"
        exit -1
    fi

    OUT_LENGTH=${#OUT}
    
    # Min length = "device" | "vendor"
    # Prevent `rm -rf /` for example.
    if [[ "$OUT_LENGTH" -lt 6 ]]; then
        error "Provided out directory path too short!"
        error "This check was made to prevent dangerous consequences in some branches if the function."
        error "Make sure you have specified the path to the output directory correctly."
        exit -1
    fi

	if [ -e "$OUT/.lock-setup" ]; then
	    echo "You have lock-file to prevent local changes overwrite! Skipping that repo..."
	    return
	fi

    REPO_URI="$1/$2"
    REPO_URL="https://github.com/$REPO_URI"

    RESET="$FORCE"

    echo "Cloning $REPO_URI [$BRANCH] to $OUT directory..."
    if test -d "$OUT/.git"; then
		echo "Repository already clonned! Updating..."
        cd "$OUT"

        REMOTE_URL="$(git remote get-url origin)"
        if [[ "$REMOTE_URL" != "$REPO_URL" ]]; then
            echo "Git remote url differs from required! Resetting..."
            git remote set-url origin "$REPO_URL" || git remote add -t "$BRANCH" origin "$REPO_URL"

            RESET=1
        fi
		
        git remote set-head origin "$BRANCH"
        git pull origin

        echo "Existing repo pulled successfully!"
    else
        if test -d "$OUT"; then
            echo "Out directory already exists, but it don't have repo!"
            echo "Redownloading repo..."

            rm -rf "$OUT"
			# no need to reset, bc we have removed dir xd
        fi

        git clone "$REPO_URL" -b "$BRANCH" "$OUT"
        echo "Clonning completed successfully!"
    fi

    cd "$CWD"
    
    if [ "$RESET" -eq 1 ]; then
        echo "Performing 'git reset'..."

        cd "$OUT"
        git reset --hard origin
        cd "$CWD"
    fi
}

echo 'IMPORTANT WARNING: Generate the vendor yourself with OS2.0.4.0ULJCNMX (Redmi K50G Latest OS2 firmware. which is Chinese)'

clone-repo LineageOS        android_device_xiaomi_sm8450-common         lineage-22.2    device/xiaomi/sm8450-common
clone-repo Ingres-Centre    proprietary_vendor_xiaomi_sm8450-common     16              vendor/xiaomi/sm8450-common
clone-repo LineageOS        android_hardware_xiaomi                     lineage-22.2    hardware/xiaomi
clone-repo Ingres-Centre    android_kernel_xiaomi_sm8450	            lineage-22.2    kernel/xiaomi/sm8450
clone-repo Ingres-Centre    android_kernel_xiaomi_sm8450-modules	    lineage-22.2    kernel/xiaomi/sm8450-modules
clone-repo Ingres-Centre    android_kernel_xiaomi_sm8450-devicetrees	lineage-22.2    kernel/xiaomi/sm8450-devicetrees

# too long repo name :|
clone-repo Ingres-Centre    android_vendor_qcom_opensource_agm 	                    lineage-22.2-caf-sm8450 hardware/qcom-caf/sm8450/audio/agm
clone-repo Ingres-Centre    android_hardware_qcom_audio-ar 	                        lineage-22.2-caf-sm8450 hardware/qcom-caf/sm8450/audio/primary-hal
clone-repo Ingres-Centre    android_vendor_qcom_opensource_arpal-lx 	            lineage-22.2-caf-sm8450 hardware/qcom-caf/sm8450/audio/pal
clone-repo Ingres-Centre    android_vendor_qcom_opensource_audioreach-graphservices lineage-22.2-caf-sm8450 hardware/qcom-caf/sm8450/audio/graphservices
