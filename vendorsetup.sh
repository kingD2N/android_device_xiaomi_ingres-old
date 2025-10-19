echo 'Starting to clone stuffs needed to build for ingres'

if [ -e ".lock-setup" ]; then
    echo "You have lock-file to prevent local changes overwrite! Exitting..."
    kill -INT $$
fi

CWD="$(realpath .)"

if [[ "$1" == "--force" ]]; then
    echo "WARNING: You are specified '--force' argument!"
	echo "WARNING: The targets to which the patches will be applied will have a git reset performed."
    FORCE=1
else
	FORCE=0
fi

error() {
    echo "$@" 1>&2;
}

reset() {
    git remote remove origin
    git remote add -t "$1" origin "$2" -f
    git checkout -b "$1" "origin/$1"
    git reset --hard origin/$1
    git pull
    cd "$CWD"
}

clone-repo() {
    REPO_OWNER="$1"
    REPO_NAME="$2"
    BRANCH=$3
    OUT=$4

    if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
        error "Not all arguments provided!"
        error "Usage: clone-repo OWNER REPO_NAME BRANCH OUT_DIR"
        kill -INT $$
    fi

    OUT_LENGTH=${#OUT}
    
    # Min length = "device" | "vendor"
    # Prevent `rm -rf /` for example.
    if [[ "$OUT_LENGTH" -lt 6 ]]; then
        error "Provided out directory path too short!"
        error "This check was made to prevent dangerous consequences in some branches if the function."
        error "Make sure you have specified the path to the output directory correctly."
        kill -INT $$
    fi

	if [ -e "$OUT/.lock-setup" ]; then
	    echo "You have lock-file to prevent local changes overwrite! Skipping that repo..."
	    return
	fi

    REPO_URI="$1/$2"
    REPO_URL="https://github.com/$REPO_URI"

    echo "Cloning $REPO_URI [$BRANCH] to $OUT directory..."

    if test -d "$OUT/.git"; then
		echo "Repository already clonned! Updating..."
        cd "$OUT"

        if [[ "$FORCE" -eq 1 ]]; then
            reset "$BRANCH" "$REPO_URL"
            return
        fi

        REMOTE="$(git remote)"
        if [[ "$REMOTE" != "origin" ]]; then
            echo "Git remote isn't 'origin'! Resetting..."
            reset "$BRANCH" "$REPO_URL"
            return
        fi

        REMOTE_URL="$(git remote get-url origin)"
        if [[ "$REMOTE_URL" != "$REPO_URL" ]]; then
            echo "Git remote url differs from required! Resetting..."
            reset "$BRANCH" "$REPO_URL"
            return
        fi

        STATUS="$(git status -sb | head -n 1)"
        if [[ "$STATUS" != "## $BRANCH" ]]; then
            echo "You have uncommited changes or using another branch! Terminating..."
			echo "Curent status of the repo is: $STATUS"
			echo "Expected status is: ## $BRANCH"
            echo "# Note: You can run 'device/xiaomi/ingres/vendorsetup.sh --force' to drop your local changes."
	    cd "$CWD"
            kill -INT $$
        fi
		
	git fetch
	git pull origin "$BRANCH"
	git reset --hard FETCH_HEAD

        echo "Existing repo pulled successfully!"
    else
        if test -d "$OUT"; then
            echo "Out directory already exists, but it don't have repo!"
            echo "Redownloading repo..."

            rm -rf "$OUT"
			# no need to reset, bc we have removed dir xd
        fi

        git clone "$REPO_URL" -b "$BRANCH" "$OUT" --recurse-submodules
        echo "Clonning completed successfully!"
    fi

    cd "$CWD"
}

echo 'IMPORTANT WARNING: Generate the vendor yourself with OS2.0.5.0ULJCNXM (Redmi K50G Latest OS2 firmware. which is Chinese)'

clone-repo LineageOS        android_device_xiaomi_sm8450-common         lineage-23.0    device/xiaomi/sm8450-common
clone-repo TheMuppets       proprietary_vendor_xiaomi_sm8450-common     lineage-23.0    vendor/xiaomi/sm8450-common
clone-repo Ingres-Centre    android_hardware_xiaomi                     lineage-23.0    hardware/xiaomi
clone-repo Ingres-Centre    android_kernel_xiaomi_sm8450	        lineage-23.0    kernel/xiaomi/sm8450
clone-repo Ingres-Centre    android_kernel_xiaomi_sm8450-modules	lineage-22.2    kernel/xiaomi/sm8450-modules
clone-repo Ingres-Centre    android_kernel_xiaomi_sm8450-devicetrees	lineage-22.2    kernel/xiaomi/sm8450-devicetrees

# external modules
# func		repo owner	repo				branch		target path
clone-repo 	Ingres-Centre	android_vendor_xiaomi_gamekey	master		vendor/xiaomi/gamekey

echo 'Looking for patch targets...'
PATCH_TARGETS="$(find device/xiaomi/ingres/patches/ -type f \( -iname '*.patch' \) -exec dirname {} \; | sort -u | sed 's/device\/xiaomi\/ingres\/patches\///')"

if [[ "$1" == "--force" ]]; then
	echo "WARNING: The targets to which the patches will be applied will have a git reset performed."
fi

while IFS= read -r TARGET; do
	BACK_PATH="$(echo "$TARGET" | sed -E 's/[a-zA-Z0-9_-]+/../g')"
	echo Applying patches to "$TARGET"

	cd "$TARGET"

	if [[ "$1" == "--force" ]]; then
		echo "Performing git reset..."
		git fetch origin 1&>/dev/null
		git reset --hard origin 1&>/dev/null
		git clean -fd 1&>/dev/null
	fi

	git am --3way "$BACK_PATH/device/xiaomi/ingres/patches/$TARGET"/*.patch | grep 'Applying: '
	cd "$BACK_PATH"
done < <(echo "$PATCH_TARGETS")
