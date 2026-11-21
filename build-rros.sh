#!/usr/bin/env bash
#
# Build ResurrectedRemix OS 17 (Android 17, basis LineageOS 24) untuk POCO F4 GT (ingres) - satu perintah.
#
#   bash build-rros.sh            # sync + build (otomatis jalan di byobu)
#   bash build-rros.sh sync       # hanya sync source
#   bash build-rros.sh build      # hanya build (lanjut dari build sebelumnya)
#   bash build-rros.sh status     # lihat progres build yang sedang jalan
#   bash build-rros.sh upload     # upload ulang isi ~/hasil-rros ke GoFile
#   bash build-rros.sh clean      # hapus hasil build lama (out/) lalu berhenti
#   bash build-rros.sh bersih ~/aospa   # hapus source ROM lain / folder lama
#   bash build-rros.sh reset-ingres     # hapus repo ingres/xiaomi lama lalu sync ulang
#   bash build-rros.sh keys       # (sekali saja) buat kunci tanda tangan pribadi di ~/.android-certs
#   bash build-rros.sh sign       # tandatangani hasil build yang sudah ada (tanpa build ulang penuh)
#
# Pengaturan (opsional, isi sebelum perintah, contoh: VARIANT=userdebug bash build-rros.sh):
#   SRC=~/rros         folder source
#   JOBS=<angka>       jumlah job build (default: otomatis dari CPU & RAM)
#   VARIANT=user       user (rilis, default) / userdebug / eng
#   GAPPS=1            build dengan GApps (default, vendor/gms bawaan RROS)
#   GAPPS=0            build vanilla tanpa GApps
#   GAPPS=both         build dua-duanya berurutan (GApps lalu vanilla)
#   DECRYPT=0          /data terenkripsi seperti biasa (default: decrypt)
#   GOFILE=0           jangan upload hasil ke GoFile (default: upload otomatis)
#   GOFILE_TOKEN=xxx   token akun GoFile (opsional)
#   SIGN=0             jangan tandatangani (default: otomatis kalau kunci sudah dibuat dengan 'keys')
#   KEYS_DIR=~/.android-certs   folder kunci tanda tangan

set -uo pipefail

ROM=rros
ROM_NAME="ResurrectedRemix OS 17"
ROM_MANIFEST="https://github.com/ResurrectedRemixOS/manifest"; ROM_BRANCH="rr-17.0"
SRC="${SRC:-$HOME/rros}"
VARIANT="${VARIANT:-user}"
SESSION="rros"
KEYS_DIR="${KEYS_DIR:-$HOME/.android-certs}"
LOG="$HOME/build.log"
MANIFEST_URL="https://raw.githubusercontent.com/kingD2N/android_device_xiaomi_ingres-old/rros-17.0/local_manifests/rros.xml"
HASIL_DIR="$HOME/hasil-rros"
SCRIPT="$(readlink -f "$0")"
CMD="${1:-all}"

ok()   { echo -e "\033[1;32m[OK]\033[0m $*"; }
info() { echo -e "\033[1;34m[..]\033[0m $*"; }
err()  { echo -e "\033[1;31m[GAGAL]\033[0m $*" >&2; }

# ---------------------------------------------------------------- status
if [ "$CMD" = "status" ]; then
    if [ -f "$LOG" ]; then
        grep -o '\[ *[0-9]*% [0-9]*/[0-9]*\]' "$LOG" | tail -n 1
        tail -n 3 "$LOG"
    else
        echo "Belum ada build.log"
    fi
    byobu ls 2>/dev/null | grep -q "^$SESSION" && echo "Sesi byobu '$SESSION' masih berjalan." \
        || echo "Tidak ada sesi byobu '$SESSION'."
    exit 0
fi

# ------------------------------------------------- bersihkan server
if [ "$CMD" = "bersih" ]; then
    shift
    echo "Ruang disk sekarang:"
    df -h "$HOME" | tail -n 1
    echo
    echo "Isi folder home (terbesar dulu):"
    du -sh "$HOME"/* "$HOME"/.ccache "$HOME"/.cache 2>/dev/null | sort -rh | head -n 15
    echo
    targets=""
    others=()
    for r in "$HOME"/*/.repo; do [ -d "$r" ] && others+=("$(dirname "$r")"); done
    for d in "${others[@]}" "$@"; do
        [ -e "$d" ] || continue
        case "$(readlink -f "$d")" in
            "$(readlink -f "$HOME")"|"$(readlink -f "$SRC")"|"$SCRIPT") echo "Lewati $d (tidak boleh dihapus)"; continue ;;
        esac
        targets="$targets $d"
    done
    if [ -z "$targets" ]; then
        ok "Tidak ada folder lama untuk dihapus."
        exit 0
    fi
    echo "Yang akan DIHAPUS PERMANEN:"
    for d in $targets; do echo "   $d"; done
    echo "Folder hasil-* (zip ROM) tidak ikut dihapus."
    read -r -p "Ketik YA lalu Enter untuk menghapus: " jawab
    [ "$jawab" = "YA" ] || { info "Batal, tidak ada yang dihapus."; exit 0; }
    for s in los24 aospa lunaris evox pixelos alpha axion ascp infinity uwu crdroid rros; do
        [ "$s" = "$SESSION" ] && [ -n "${TMUX:-}" ] && continue
        byobu kill-session -t "$s" >/dev/null 2>&1 && info "Sesi byobu '$s' dihentikan"
    done
    info "Menghapus... (bisa 5-20 menit, jangan tutup Termius)"
    # shellcheck disable=SC2086
    rm -rf $targets
    ok "Selesai. Ruang disk sekarang:"
    df -h "$HOME" | tail -n 1
    exit 0
fi

# ------------------------------------------- selalu jalan di dalam byobu
if [ -z "${TMUX:-}" ] && [ -z "${STY:-}" ] && [ "$CMD" != "clean" ] && [ "$CMD" != "reset-ingres" ] && [ "$CMD" != "keys" ]; then
    command -v byobu >/dev/null || { err "byobu tidak ada di server"; exit 1; }
    if byobu ls 2>/dev/null | grep -q "^$SESSION"; then
        err "Sesi '$SESSION' sudah ada (satu build per akun). Masuk dengan: byobu attach -t $SESSION"
        exit 1
    fi
    envs="SRC='$SRC' VARIANT='$VARIANT' GOOGLE_INSTALLER='${GOOGLE_INSTALLER:-0}' GAPPS='${GAPPS:-1}' DECRYPT='${DECRYPT:-1}' GOFILE='${GOFILE:-1}' GOFILE_TOKEN='${GOFILE_TOKEN:-}' JOBS='${JOBS:-}' SIGN='${SIGN:-auto}' KEYS_DIR='$KEYS_DIR'"
    byobu new-session -d -s "$SESSION" "$envs bash '$SCRIPT' $CMD; echo; echo 'Selesai. Tekan Enter untuk menutup.'; read"
    ok "Build berjalan di sesi byobu '$SESSION' (aman kalau Termius ditutup)."
    echo "   Lihat layar build : byobu attach -t $SESSION   (keluar lagi: F6)"
    echo "   Cek progres saja  : bash $SCRIPT status"
    exit 0
fi

# ------------------------------------------------------------- persiapan
check_tools() {
    local miss=""
    for t in git git-lfs python3 curl ccache zip; do command -v "$t" >/dev/null || miss="$miss $t"; done
    if ! command -v repo >/dev/null; then
        info "Memasang repo ke ~/bin"
        mkdir -p "$HOME/bin"
        curl -s https://storage.googleapis.com/git-repo-downloads/repo > "$HOME/bin/repo" && chmod a+x "$HOME/bin/repo"
        export PATH="$HOME/bin:$PATH"
    fi
    [ -z "$miss" ] || { err "Alat belum terpasang di server:$miss (minta pemilik server memasangnya)"; exit 1; }
    git config --global user.name >/dev/null || git config --global user.name "kingD2N"
    git config --global user.email >/dev/null || git config --global user.email "114895723+kingD2N@users.noreply.github.com"
    git lfs install >/dev/null 2>&1 || true
    CCACHE_EXEC="$(command -v ccache)"
    export USE_CCACHE=1 CCACHE_EXEC CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
    ccache -M 50G >/dev/null 2>&1 || true
}

check_disk() {
    local need_gb=$1 avail_gb
    [ "${SKIP_DISK_CHECK:-0}" = 1 ] && return 0
    avail_gb=$(df -BG --output=avail "$HOME" | tail -n 1 | tr -dc '0-9')
    info "Ruang disk kosong: ${avail_gb} GB"
    if [ "${avail_gb:-0}" -lt "$need_gb" ]; then
        err "Ruang disk kurang dari ${need_gb} GB. Hapus build lama: bash $SCRIPT clean"
        exit 1
    fi
}

# ------------------------------------------------- tambalan source
# folder device/vendor/kernel xiaomi sisa percobaan lama (tidak ada di manifest)
# tetap dibaca soong -> modul ganda ("multiple rules generate ..."). Pindahkan.
# path project dari manifest (repo list -p bisa tidak lengkap, jadi baca XML juga)
manifest_paths() {
    { repo list -p 2>/dev/null
      cat .repo/manifests/*.xml .repo/manifests/snippets/*.xml .repo/local_manifests/*.xml 2>/dev/null \
        | grep -o 'path="[^"]*"' | cut -d'"' -f2
    } | sort -u
}

# folder yang tercantum di manifest tapi sempat dipindah ke sisa-lama -> kembalikan
restore_leftovers() {
    local known d bak="$HOME/rros-sisa-lama"
    [ -d "$bak" ] || return 0
    known=$(manifest_paths)
    for d in $(cd "$bak" && find device vendor kernel hardware -mindepth 1 -maxdepth 2 -type d 2>/dev/null); do
        grep -qx "$d" <<<"$known" || continue
        [ -e "$d" ] && continue
        mkdir -p "$(dirname "$d")"
        info "Mengembalikan $d dari $bak"
        mv "$bak/$d" "$d"
    done
}

move_leftovers() {
    local known d bak="$HOME/rros-sisa-lama"
    known=$(manifest_paths)
    [ -n "$known" ] || return 0
    for d in device/xiaomi/* vendor/xiaomi/* kernel/xiaomi/* hardware/xiaomi*; do
        [ -d "$d" ] || continue
        grep -qx "$d" <<<"$known" && continue
        # folder induk dari repo lain (mis. vendor/xiaomi/camera/...) jangan disentuh
        grep -q "^$d/" <<<"$known" && continue
        mkdir -p "$bak/$(dirname "$d")"
        info "Memindahkan folder sisa lama: $d -> $bak/$d"
        rm -rf "${bak:?}/$d"
        mv "$d" "$bak/$d"
    done
}

# GameKeys: libevdev (C) ada di submodule third_party/cpp/evdev (diambil lewat
# local manifest). Crate rust-nya cuma dipakai gamekeyd (vendor), jadi dibuat
# vendor-only agar tidak butuh varian core dari libevdev.
fix_gamekey() {
    local g=vendor/xiaomi/gamekey
    [ -d "$g" ] || return 0
    if [ ! -f "$g/third_party/cpp/evdev/Android.bp" ]; then
        info "Mengambil libevdev untuk GameKeys"
        repo sync -c -j1 --force-sync "$g/third_party/cpp/evdev" || true
    fi
    [ -f "$g/third_party/cpp/evdev/Android.bp" ] || { err "libevdev GameKeys tidak ada ($g/third_party/cpp/evdev)"; exit 1; }
    if grep -qs 'vendor_available *: *true' "$g"/third_party/rust/*/Android.bp; then
        sed -i 's/vendor_available *: *true/vendor: true/' "$g"/third_party/rust/*/Android.bp
        info "Tambalan: crate rust GameKeys -> vendor: true"
    fi
    # AIDL Rust baru tidak lagi membuat ISettingsServiceDefaultRef (import tak terpakai)
    if grep -qs 'ISettingsServiceDefaultRef' "$g/daemon/src/binder_service.rs"; then
        sed -i 's/, *ISettingsServiceDefaultRef//' "$g/daemon/src/binder_service.rs"
        info "Tambalan: GameKeys tanpa ISettingsServiceDefaultRef"
    fi
    # Android 17: rustutils::system_properties pindah ke rustutils::android::system_properties
    if [ -f system/librustutils/rustutils/src/android/system_properties.rs ] \
        && grep -qs 'rustutils::system_properties' "$g"/daemon/src/*.rs; then
        sed -i 's/rustutils::system_properties/rustutils::android::system_properties/g' "$g"/daemon/src/*.rs
        info "Tambalan: GameKeys -> rustutils::android::system_properties"
    fi
}
# Dolby Vision: composer Qualcomm sengaja tidak melaporkan Dolby Vision di kemampuan
# HDR layar. Tambahkan ke daftar (HDR10/HLG/HDR10+ tetap). SM8450 tidak punya decoder
# Dolby Vision, jadi ini hanya kemampuan layar yang dilaporkan.
fix_dolby_vision() {
    local f=hardware/qcom-caf/sm8450/display/composer/hwc_display.cpp
    [ -f "$f" ] || return 0
    grep -q 'Hdr::DOLBY_VISION) /\* Skip list \*/' "$f" || return 0
    sed -i \
        -e 's|num_types = UINT32(Hdr::HDR10_PLUS) - 1;|num_types = UINT32(Hdr::HDR10_PLUS);|' \
        -e 's|num_types = UINT32(Hdr::HLG) - 1;|num_types = UINT32(Hdr::HLG);|' \
        -e 's|while (type == static_cast<int32_t>(Hdr::DOLBY_VISION) /\* Skip list \*/) {|while (type == 0 /* ingres: Dolby Vision ikut dilaporkan */) {|' \
        -e 's|if (type > (num_types + 1)) {|if (type > static_cast<int32_t>(num_types)) {|' "$f"
    info "Tambalan: composer melaporkan Dolby Vision"
}

# Launcher3 RROS: gestur "geser ke atas dari aplikasi" bawaan (Setelan Launcher > Recents >
# Gestur) mendapat aksi ketiga "Gelembung aplikasi" selain Freeform dan Layar terpisah.
# Pilih aksinya di pengaturan itu, lalu geser ke atas melewati batas (ada getar) dan lepas
# -> aplikasi dibuka sebagai gelembung. Gaya Recents (iOS dll) tidak disentuh.
# Patch disimpan di device tree.
L3_DIR=packages/apps/Launcher3
L3_PATCH="$SRC/device/xiaomi/ingres/patches/launcher3/0001-overview-gesture-app-bubble.patch"
# Kembalikan berkas yang disentuh sebuah tambalan ke kondisi repo (dipakai kalau versi
# tambalan lama masih terpasang dan tidak cocok dengan tambalan baru).
reset_patch_files() {
    local dir="$1" patch="$2" f
    while IFS= read -r f; do
        if git -C "$dir" ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
            git -C "$dir" checkout -q -- "$f" 2>/dev/null || true
        else
            rm -f "$dir/$f"
        fi
    done < <(sed -n 's#^diff --git a/\(.*\) b/.*#\1#p' "$patch")
}
fix_launcher3_bubble() {
    [ -f "$L3_PATCH" ] && [ -f "$L3_DIR/quickstep/src/com/android/quickstep/AbsSwipeUpHandler.java" ] || return 0
    git -C "$L3_DIR" apply --check -R "$L3_PATCH" 2>/dev/null && return 0   # sudah terpasang
    if ! git -C "$L3_DIR" apply "$L3_PATCH" 2>/dev/null; then
        # mungkin tambalan versi lama masih terpasang: bersihkan lalu pasang ulang
        reset_patch_files "$L3_DIR" "$L3_PATCH"
        git -C "$L3_DIR" apply "$L3_PATCH" 2>/dev/null || {
            err "Tambalan Launcher3 gelembung tidak cocok lagi (Launcher3 RROS berubah), dilewati"
            return 0
        }
    fi
    info "Tambalan: Launcher3 gestur geser ke atas -> aksi gelembung aplikasi"
}

# Refresh rate per aplikasi (Setelan > Layar > Refresh rate per aplikasi), seperti Lunaris.
# Framework: WindowManager (RefreshRatePolicy) memakai pilihan pengguna untuk aplikasi yang
# sedang tampil. Settings: halaman pilihan Hz tiap aplikasi. Pilihan disimpan di
# Settings.System "per_app_refresh_rate". Rate di atas batas sistem butuh Smooth Display nyala.
FW_PERAPP_PATCH="$SRC/device/xiaomi/ingres/patches/frameworks_base/0002-per-app-refresh-rate.patch"
SET_PERAPP_PATCH="$SRC/device/xiaomi/ingres/patches/settings/0001-per-app-refresh-rate.patch"
# Settings > Aplikasi > Gaya pemasang paket (0 = AOSP, 1 = dialog, 2 = lembar bawah), dipakai
# bersama tambalan PackageInstaller Lunaris (fix_package_installer).
SET_PISTYLE_PATCH="$SRC/device/xiaomi/ingres/patches/settings/0002-package-installer-style.patch"
# Pasang satu tambalan dengan aman: lewati kalau sudah terpasang, bersihkan versi lama kalau
# perlu. $1=folder repo, $2=berkas tambalan, $3=berkas penanda, $4=nama untuk pesan.
apply_tree_patch() {
    local dir="$1" patch="$2" marker="$3" name="$4"
    [ -f "$patch" ] && [ -f "$dir/$marker" ] || return 0
    git -C "$dir" apply --check -R "$patch" 2>/dev/null && return 0   # sudah terpasang
    if ! git -C "$dir" apply "$patch" 2>/dev/null; then
        reset_patch_files "$dir" "$patch"
        git -C "$dir" apply "$patch" 2>/dev/null || {
            err "Tambalan $name tidak cocok lagi (source RROS berubah), dilewati"
            return 0
        }
    fi
    info "Tambalan: $name"
}
fix_per_app_refresh_rate() {
    apply_tree_patch frameworks/base "$FW_PERAPP_PATCH" \
        services/core/java/com/android/server/wm/RefreshRatePolicy.java \
        "refresh rate per aplikasi (framework)"
    apply_tree_patch packages/apps/Settings "$SET_PERAPP_PATCH" \
        res/xml/display_settings.xml "refresh rate per aplikasi (Settings)"
    apply_tree_patch packages/apps/Settings "$SET_PISTYLE_PATCH" \
        res/xml/apps.xml "gaya pemasang paket (Settings)"
}

# ------------------------------------------------------------- GApps
# GApps: RROS membawa vendor/gms sendiri lewat manifest-nya (GitLab osm1019), jadi tidak
# ada local manifest GApps tambahan. GAPPS=0 = WITH_GMS=false (vanilla).
want_gms() { [ "${GAPPS:-1}" != 0 ] && [ "${GAPPS:-1}" != vanilla ]; }

# Pixel Launcher di vendor_gms butuh overlay Pixel (recents) yang tidak ada di LineageOS,
# jadi selalu dibuang: layar utama tetap Trebuchet dengan fitur geser-ke-gelembung.
fix_gms_launcher() {
    local f
    for f in vendor/gms/gms*.mk; do
        [ -f "$f" ] || continue
        grep -q '^[[:space:]]*NexusLauncherRelease[[:space:]]*\\$' "$f" || continue
        sed -i '/^[[:space:]]*NexusLauncherRelease[[:space:]]*\\$/d' "$f"
        info "Tambalan: Pixel Launcher dibuang dari GApps (tetap Trebuchet)"
    done
    return 0
}

# Pengaman launcher (belajar dari EvoX): Launcher3 crash terus kalau recents/home menunjuk ke
# Pixel Launcher padahal Pixel Launcher tidak ikut terpasang. Overlay dicari dari ISI-nya,
# bukan dari nama foldernya, supaya perubahan nama di vendor_gms tidak lolos diam-diam.
# Di RROS Pixel Launcher tidak dibuang (fix_gms_launcher tidak dipakai), jadi kombinasi itu
# hanya muncul kalau vendor_gms berubah; lebih baik berhenti di sini daripada build berjam-jam.
LAUNCHER_SCAN_DIRS="vendor/gms vendor/rr vendor/extras device/xiaomi"
PIXEL_RECENTS_RE='name="config_(recentsComponentName|secondaryHomePackage)">com\.google\.android\.apps\.nexuslauncher'
GMS_NEXUS_RE='^[[:space:]]*NexusLauncherRelease[[:space:]]*\\$'
pixel_launcher_refs() {
    local d dirs=""
    for d in $LAUNCHER_SCAN_DIRS; do [ -d "$d" ] && dirs="$dirs $d"; done
    [ -n "$dirs" ] || return 0
    grep -rlIE --include='*.xml' "$PIXEL_RECENTS_RE" $dirs 2>/dev/null || true
}
verify_launcher_overlay() {
    want_gms || return 0
    [ -d vendor/gms ] || return 0
    local refs f has_nexus=0
    refs=$(pixel_launcher_refs)
    for f in vendor/gms/gms*.mk; do
        [ -f "$f" ] || continue
        grep -q "$GMS_NEXUS_RE" "$f" && has_nexus=1
    done
    if [ -n "$refs" ] && [ "$has_nexus" = 0 ]; then
        err "Recents/home menunjuk ke Pixel Launcher, tapi Pixel Launcher tidak ikut terpasang:"
        echo "$refs" | sed 's/^/   /' >&2
        err "Launcher3 akan crash. Periksa vendor_gms (NexusLauncherRelease hilang dari gms*.mk)."
        return 1
    fi
    return 0
}

# APK yang tidak terdaftar di .gitattributes vendor_gms ter-checkout sebagai pointer LFS
# (mis. AmbientStreaming): unduh isinya, kalau gagal keluarkan dari daftar paket.
fix_gms_lfs() {
    [ -d vendor/gms ] || return 0
    local apk name rel
    while IFS= read -r apk; do
        head -c 40 "$apk" | grep -q '^version https://git-lfs' || continue
        rel="${apk#vendor/gms/}"
        if (cd vendor/gms && git lfs smudge "$rel" < "$rel" > "$rel.lfs") 2>/dev/null \
                && [ "$(head -c 2 "$apk.lfs")" = PK ]; then
            mv -f "$apk.lfs" "$apk"
            info "Tambalan: $(basename "$apk") diunduh dari LFS"
        else
            rm -f "$apk.lfs"
            name="$(basename "$(dirname "$apk")")"
            sed -i "/^[[:space:]]*${name}[[:space:]]*\\\\\$/d" vendor/gms/gms*.mk
            info "Tambalan: $name dilewati (APK dari LFS tidak bisa diunduh)"
        fi
        if [ -f "$(dirname "$apk")/Android.mk" ] && ! grep -q LOCAL_ENFORCE_USES_LIBRARIES "$(dirname "$apk")/Android.mk"; then
            sed -i 's|^include \$(BUILD_PREBUILT)|LOCAL_ENFORCE_USES_LIBRARIES := false\n&|' "$(dirname "$apk")/Android.mk"
        fi
    done < <(find vendor/gms -name '*.apk' -size -2k 2>/dev/null)
}

# PackageInstaller: tampilan pemasang aplikasi Lunaris (Compose Material 3 Expressive,
# port dari Lunaris-AOSP/frameworks_base 16.2). Gaya bisa diganti tanpa build ulang:
#   settings put secure package_installer_style 2   (0 = AOSP, 1 = dialog, 2 = bottom sheet)
# Build GApps memasang GooglePackageInstaller (APK prebuilt) yang menimpa PackageInstaller,
# jadi APK itu dibuang dari daftar paket GApps. GOOGLE_INSTALLER=1 = tetap pemasang Google.
PI_PATCH="$SRC/device/xiaomi/ingres/patches/frameworks_base/0001-PackageInstaller-Lunaris-expressive-UI.patch"
PI_GMS_DIR=vendor/gms
fix_package_installer() {
    [ -f "$PI_PATCH" ] && [ -d frameworks/base/packages/PackageInstaller ] || return 0
    if git -C frameworks/base apply --check -R "$PI_PATCH" 2>/dev/null; then   # sudah terpasang
        drop_google_installer
        return 0
    fi
    if git -C frameworks/base apply "$PI_PATCH"; then
        info "Tambalan: PackageInstaller tampilan Lunaris"
    else
        err "Tambalan PackageInstaller Lunaris tidak cocok lagi (frameworks/base berubah), dilewati"
        return 0
    fi
    drop_google_installer
}
drop_google_installer() {
    [ "${GOOGLE_INSTALLER:-0}" = 1 ] && return 0
    [ -d "$PI_GMS_DIR" ] || return 0
    local f changed=0
    while IFS= read -r f; do
        sed -i -E '/^[[:space:]]*GooglePackageInstaller[[:space:]]*(\\)?$/d' "$f"
        changed=1
    done < <(grep -rlE '^[[:space:]]*GooglePackageInstaller[[:space:]]*(\\)?$' "$PI_GMS_DIR" --include='*.mk' 2>/dev/null)
    [ $changed = 1 ] && info "Tambalan: GooglePackageInstaller dibuang, GApps pakai PackageInstaller Lunaris"
    return 0
}

unpatch_source() {
    if [ -f "$PI_PATCH" ] && git -C frameworks/base apply --check -R "$PI_PATCH" 2>/dev/null; then
        git -C frameworks/base apply -R "$PI_PATCH" || true
    fi
    git -C "$PI_GMS_DIR" checkout -q -- . 2>/dev/null || true
    git -C vendor/gms checkout -q -- . 2>/dev/null || true
    git -C hardware/qcom-caf/sm8450/display checkout -q -- composer/hwc_display.cpp 2>/dev/null || true
    git -C vendor/xiaomi/gamekey checkout -q -- third_party/rust daemon/src 2>/dev/null || true
    if [ -f "$L3_PATCH" ] && git -C "$L3_DIR" apply --check -R "$L3_PATCH" 2>/dev/null; then
        git -C "$L3_DIR" apply -R "$L3_PATCH" || true
    fi
    if [ -f "$FW_PERAPP_PATCH" ] && git -C frameworks/base apply --check -R "$FW_PERAPP_PATCH" 2>/dev/null; then
        git -C frameworks/base apply -R "$FW_PERAPP_PATCH" || true
    fi
    if [ -f "$SET_PERAPP_PATCH" ] && git -C packages/apps/Settings apply --check -R "$SET_PERAPP_PATCH" 2>/dev/null; then
        git -C packages/apps/Settings apply -R "$SET_PERAPP_PATCH" || true
    fi
    if [ -f "$SET_PISTYLE_PATCH" ] && git -C packages/apps/Settings apply --check -R "$SET_PISTYLE_PATCH" 2>/dev/null; then
        git -C packages/apps/Settings apply -R "$SET_PISTYLE_PATCH" || true
    fi
}
patch_source() {
    fix_dolby_vision
    fix_gamekey
    fix_gms_lfs
    fix_launcher3_bubble
    fix_per_app_refresh_rate
    fix_package_installer
    # (fix_gms_launcher sengaja tidak dipanggil: Pixel Launcher dibiarkan; lihat verify_launcher_overlay)
}

# ------------------------------------------------------------------ sync
do_sync() {
    # aturan server: hanya 1 source ROM per akun
    local other
    for other in "$HOME"/*/.repo; do
        [ -d "$other" ] || continue
        other="$(dirname "$other")"
        [ "$(readlink -f "$other")" = "$(readlink -f "$SRC")" ] && continue
        err "Ada source ROM lain: $other (server hanya mengizinkan 1 source ROM)."
        echo "   Simpan dulu zip-nya kalau perlu, lalu hapus: bash $SCRIPT bersih $other"
        exit 1
    done
    mkdir -p "$SRC" && cd "$SRC" || exit 1
    local cur_url cur_branch
    cur_url=$(git -C .repo/manifests config remote.origin.url 2>/dev/null || true)
    cur_branch=$(git -C .repo/manifests config branch.default.merge 2>/dev/null | sed 's#refs/heads/##' || true)
    if [ ! -d .repo ]; then
        check_disk 300
        info "repo init $ROM_NAME"
        repo init -u "$ROM_MANIFEST" -b "$ROM_BRANCH" \
            --git-lfs --no-clone-bundle --depth=1 || { err "repo init gagal"; exit 1; }
    elif [ "${cur_url%.git}" != "$ROM_MANIFEST" ] || { [ -n "$cur_branch" ] && [ "$cur_branch" != "$ROM_BRANCH" ]; }; then
        info "Pindah manifest ke $ROM_NAME (source yang sama dipakai ulang)"
        repo init -u "$ROM_MANIFEST" -b "$ROM_BRANCH" \
            --git-lfs --no-clone-bundle --depth=1 || { err "repo init gagal"; exit 1; }
    fi
    mkdir -p .repo/local_manifests
    # local manifest lama (percobaan sebelumnya) bisa bentrok, singkirkan
    for f in .repo/local_manifests/*.xml; do
        case "$(basename "$f")" in rros.xml) continue ;; esac
        [ -e "$f" ] && mv -f "$f" "$f.bak" && info "Menyingkirkan $(basename "$f")"
    done
    curl -fsSL -o .repo/local_manifests/rros.xml "$MANIFEST_URL" || { err "Gagal unduh local manifest"; exit 1; }
    if want_gms; then
        info "GApps: vendor/gms bawaan manifest RROS ikut di-sync"
    fi

    # sisa percobaan lama: folder ingres/xiaomi yang bukan hasil repo ini bikin
    # "unsupported checkout state" dan Android.bp lama (vendor common salah versi)
    reset_project() {
        local rel="${1#"$SRC"/}"; rel="${rel%/.git}"; rel="${rel%/}"
        case "$rel" in ""|/*|*..*) return ;; esac
        info "Menghapus checkout lama: $rel"
        rm -rf "${SRC:?}/$rel" "${SRC:?}/.repo/projects/$rel.git"
    }

    unpatch_source
    local n slog="$HOME/sync-rros.log"
    for n in 1 2 3; do
        info "repo sync (percobaan $n/3)"
        repo sync -c -j8 --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune --force-remove-dirty 2>&1 | tee "$slog"
        [ "${PIPESTATUS[0]}" -eq 0 ] && break
        if grep -q 'unsupported checkout state\|not a git repository\|already exists and is not' "$slog"; then
            grep -o '/[^ :]*\.git: unsupported checkout state' "$slog" | sed 's/: unsupported checkout state//' \
                | sort -u | while read -r d; do reset_project "$d"; done
            continue
        fi
        [ "$n" -eq 3 ] && { err "repo sync gagal 3 kali. Coba lagi nanti: bash $SCRIPT sync"; exit 1; }
        sleep 30
    done
    if grep -q 'unsupported checkout state' "$slog" 2>/dev/null; then
        err "Masih ada checkout rusak. Jalankan: bash $SCRIPT reset-ingres  lalu  bash $SCRIPT"
        exit 1
    fi

    # pastikan bagian penting ingres benar-benar lengkap
    if ! [ -f vendor/xiaomi/ingres/ingres-vendor.mk ] \
        || ! [ -f device/xiaomi/sm8450-common/common.mk ] \
        || ! [ -f kernel/xiaomi/sm8450/arch/arm64/configs/vendor/ingres_GKI.config ]; then
        restore_leftovers
        info "Mengulang sync repo ingres yang belum lengkap"
        repo sync -c -j1 --force-sync device/xiaomi/ingres device/xiaomi/sm8450-common vendor/xiaomi/ingres kernel/xiaomi/sm8450 || true
    fi
    restore_leftovers
    move_leftovers
    patch_source
    verify_launcher_overlay || err "Periksa launcher/vendor_gms sebelum build"
    ok "Source siap di $SRC"
}

# Header kernel hasil generate (generated_kernel_includes) hanya dibuat ulang kalau
# Makefile/include kernel berubah. Kalau header UAPI vendor (audio/display) tidak
# lengkap, hapus supaya dibuat ulang dari kernel yang sekarang.
fix_kernel_headers() {
    local g=out/soong/.intermediates/vendor/rr/build/soong/generated_kernel_includes
    [ -d "$g" ] || return 0
    if [ -z "$(find "$g" -path '*usr/include/display/drm/sde_drm.h' -print -quit 2>/dev/null)" ] \
        || [ -z "$(find "$g" -path '*usr/include/audio/linux/msm_audio.h' -print -quit 2>/dev/null)" ]; then
        info "Header kernel tidak lengkap, dibuat ulang"
        rm -rf "$g"
    fi
}

# ----------------------------------------------------------------- build
do_build() {
    cd "$SRC" 2>/dev/null && [ -f build/envsetup.sh ] || { err "Source belum ada. Jalankan: bash $SCRIPT sync"; exit 1; }
    if [ -d out/target/product/ingres ]; then check_disk 20; else check_disk 160; fi

    local jobs ram_gb
    ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    jobs=${JOBS:-$(( ram_gb / 2 ))}
    [ "$jobs" -gt "$(nproc)" ] && jobs=$(nproc)
    [ "$jobs" -lt 2 ] && jobs=2
    info "Build dengan $jobs job (RAM ${ram_gb} GB, CPU $(nproc) core)"

    restore_leftovers
    move_leftovers
    patch_source
    verify_launcher_overlay || exit 1
    fix_kernel_headers
    info "Varian build: $VARIANT"
    if [ "${DECRYPT:-1}" = 0 ]; then export TARGET_DECRYPTED_DATA=false; info "/data terenkripsi"; else export TARGET_DECRYPTED_DATA=true; info "/data tanpa enkripsi (decrypt)"; fi
    set +u   # envsetup.sh / breakfast memakai variabel yang belum diisi
    local start rc
    start=$(date +%s)
    info "ROM: $ROM_NAME"
    # shellcheck disable=SC1091
    source build/envsetup.sh >/dev/null
    local gms_list g
    case "${GAPPS:-1}" in
        both|2|semua) gms_list="true false" ;;
        0|vanilla)    gms_list="false" ;;
        *)            gms_list="true" ;;
    esac
    if [[ "$gms_list" == *true* ]] && ! [ -f vendor/gms/gms_full.mk ]; then
        err "GApps belum di-sync (vendor/gms tidak ada). Jalankan: bash $SCRIPT   (sync + build)"
        echo "   atau build vanilla: GAPPS=0 bash $SCRIPT build"
        exit 1
    fi
    mkdir -p "$HASIL_DIR"
    for g in $gms_list; do
        build_variant "$g" "$jobs"
    done
    echo "Durasi total: $(( ($(date +%s) - start) / 60 )) menit"
    ok "BUILD BERHASIL"
    ls -lh "$HASIL_DIR"
    if [ "${GOFILE:-1}" != 0 ]; then
        do_upload || echo "Upload GoFile gagal. Ulangi dengan: bash $SCRIPT upload"
    else
        echo "Ambil file di folder $HASIL_DIR lewat SFTP Termius."
    fi
}

# ------------------------------------------------- tanda tangan (kunci pribadi)
# Kunci rilis sendiri menggantikan kunci uji AOSP. Simpan ~/.android-certs (cadangkan!),
# jangan pernah dibagikan/di-upload. Ganti kunci = wajib wipe data (tanda tangan app sistem berubah).
CORE_KEYS="releasekey platform shared media networkstack bluetooth sdk_sandbox nfc"

have_keys() { [ -f "$KEYS_DIR/releasekey.pk8" ] && [ -f "$KEYS_DIR/releasekey.x509.pem" ] && [ -f "$KEYS_DIR/platform.pk8" ]; }
want_sign() { [ "${SIGN:-auto}" != 0 ] && have_keys; }

make_one_key() {   # $1=nama kunci (tanpa sandi); tidak pernah menimpa
    local k="$1" subj="/C=ID/ST=Indonesia/L=Jakarta/O=kingD2N/OU=RROS/CN=$1"
    [ -f "$KEYS_DIR/$k.pk8" ] && return 0
    echo | "$SRC/development/tools/make_key" "$KEYS_DIR/$k" "$subj" >/dev/null 2>&1 || return 1
    openssl pkcs8 -in "$KEYS_DIR/$k.pk8" -inform DER -nocrypt -out "$KEYS_DIR/$k.pem" 2>/dev/null || return 1
    chmod 600 "$KEYS_DIR/$k".* 2>/dev/null
    return 0
}

do_keys() {
    [ -x "$SRC/development/tools/make_key" ] || { err "make_key tidak ada di $SRC/development/tools (sync dulu: bash $SCRIPT sync)"; exit 1; }
    command -v openssl >/dev/null || { err "openssl tidak terpasang di server"; exit 1; }
    mkdir -p "$KEYS_DIR"; chmod 700 "$KEYS_DIR"
    local k made=0
    for k in $CORE_KEYS; do
        if [ -f "$KEYS_DIR/$k.pk8" ]; then continue; fi
        info "Membuat kunci: $k"
        make_one_key "$k" || { err "Gagal membuat kunci $k"; exit 1; }
        made=$((made + 1))
    done
    if [ "$made" -eq 0 ]; then
        ok "Kunci sudah ada di $KEYS_DIR (tidak ditimpa)."
    else
        ok "$made kunci dibuat di $KEYS_DIR"
    fi
    echo "PENTING:"
    echo " 1. Cadangkan folder $KEYS_DIR (unduh lewat SFTP Termius, simpan aman). Kunci hilang = update berikutnya tidak bisa dirilis dengan tanda tangan yang sama."
    echo " 2. JANGAN dibagikan / dikirim ke chat / di-upload ke GitHub."
    echo " 3. Build pertama yang bertanda tangan ini = WAJIB wipe data (Format Data) saat flash dari ROM bertanda tangan lain."
    echo "Build berikutnya (bash $SCRIPT) otomatis memakai kunci ini. Lewati sementara: SIGN=0"
}

# Tandatangani: target-files -> sign_target_files_apks -> ota_from_target_files. $1=jobs $2=zip tujuan
sign_variant() {
    local jobs="$1" dest="$2" p="out/target/product/ingres" tf work stf ota apx name base rc
    local -a args=()
    check_disk 25
    export PATH="$SRC/out/host/linux-x86/bin:$PATH"
    info "Menandatangani dengan kunci pribadi ($KEYS_DIR)"
    m target-files-package otatools -j"$jobs" 2>&1 | tee -a "$LOG"
    rc=${PIPESTATUS[0]}
    [ "$rc" -eq 0 ] || { err "m target-files-package otatools gagal (lihat $LOG)"; return 1; }
    tf=$(ls -t "$p"/obj/PACKAGING/target_files_intermediates/*-target_files*.zip 2>/dev/null | head -n 1)
    [ -n "$tf" ] || { err "target-files zip tidak ditemukan"; return 1; }
    command -v sign_target_files_apks >/dev/null && command -v ota_from_target_files >/dev/null \
        || { err "sign_target_files_apks / ota_from_target_files tidak ada (m otatools gagal?)"; return 1; }
    # kunci APEX: satu kunci per paket APEX yang ada di target-files (dibuat sekali, dipakai seterusnya)
    while read -r apx; do
        [ -n "$apx" ] || continue
        name="${apx##*/}"; base="${name%.*}"
        make_one_key "$base" || { err "Gagal membuat kunci APEX $base"; return 1; }
        args+=(--extra_apks "$name=$KEYS_DIR/$base" --extra_apex_payload_key "$name=$KEYS_DIR/$base.pem")
    done < <(python3 - "$tf" <<'PY'
import re, sys, zipfile
seen = set()
for n in zipfile.ZipFile(sys.argv[1]).namelist():
    m = re.search(r'(?:^|/)apex/([^/]+\.(?:apex|capex))$', n)
    if m and m.group(1) not in seen:
        seen.add(m.group(1)); print(m.group(1))
PY
)
    info "APEX yang ikut ditandatangani: $(( ${#args[@]} / 4 ))"
    work="out/signing"; rm -rf "$work"; mkdir -p "$work"
    stf="$work/signed-target_files.zip"; ota="$work/signed-ota.zip"
    sign_target_files_apks -o -d "$KEYS_DIR" "${args[@]}" "$tf" "$stf" 2>&1 | tee -a "$LOG" | tail -n 5
    rc=${PIPESTATUS[0]}
    if [ "$rc" -ne 0 ] || [ ! -s "$stf" ]; then
        err "sign_target_files_apks gagal (log lengkap: $LOG)"
        grep -n -B2 -A12 'Traceback\|ERROR\|Error' "$LOG" | tail -n 30
        rm -rf "$work"; return 1
    fi
    if ! ota_from_target_files -k "$KEYS_DIR/releasekey" --block --backup=true "$stf" "$ota" >>"$LOG" 2>&1; then
        info "Opsi --block/--backup tidak diterima, coba tanpa itu"
        ota_from_target_files -k "$KEYS_DIR/releasekey" "$stf" "$ota" >>"$LOG" 2>&1 || true
    fi
    [ -s "$ota" ] || { err "ota_from_target_files gagal (log lengkap: $LOG)"; tail -n 25 "$LOG"; rm -rf "$work"; return 1; }
    mv "$ota" "$dest"
    # image boot hasil tanda tangan (untuk fastboot, kalau perlu)
    unzip -o -j -q "$stf" IMAGES/boot.img IMAGES/vendor_boot.img IMAGES/dtbo.img -d "$HASIL_DIR" 2>/dev/null || true
    rm -rf "$work"
    return 0
}

# Salin hasil build ke HASIL_DIR; tandatangani kalau kunci ada. $1=gms $2=jobs
package_variant() {
    local gms="$1" jobs="$2" p="out/target/product/ingres" zip out
    zip=$(ls -t "$p"/ResurrectedRemix-*-ingres.zip 2>/dev/null | head -n 1)
    [ -n "$zip" ] || { err "Build selesai tapi zip tidak ditemukan"; exit 1; }
    out="$(basename "$zip")"
    [ "$gms" = true ] && out="${out%.zip}-GApps.zip"
    mkdir -p "$HASIL_DIR"
    if want_sign; then
        if sign_variant "$jobs" "$HASIL_DIR/${out%.zip}-signed.zip"; then
            out="${out%.zip}-signed.zip"
            ok "ROM bertanda tangan kunci pribadi (wipe data wajib kalau sebelumnya bukan kunci ini)"
        else
            err "Tanda tangan gagal -> memakai zip TANPA tanda tangan pribadi (kunci uji AOSP)"
            cp "$zip" "$HASIL_DIR/$out"
            cp $p/boot.img $p/dtbo.img $p/vendor_boot.img $p/recovery.img "$HASIL_DIR"/ 2>/dev/null
        fi
    else
        cp "$zip" "$HASIL_DIR/$out"
        cp $p/boot.img $p/dtbo.img $p/vendor_boot.img $p/recovery.img "$HASIL_DIR"/ 2>/dev/null
        [ "${SIGN:-auto}" = 0 ] || info "Kunci pribadi belum ada -> ROM memakai kunci uji AOSP. Buat sekali: bash $SCRIPT keys"
    fi
    (cd "$HASIL_DIR" && sha256sum "$out" > "$out.sha256")
    ok "Selesai: $out"
}

do_sign() {
    have_keys || { err "Kunci belum ada. Buat dulu: bash $SCRIPT keys"; exit 1; }
    cd "$SRC" 2>/dev/null && [ -f build/envsetup.sh ] || { err "Source belum ada. Jalankan: bash $SCRIPT sync"; exit 1; }
    [ -d out/target/product/ingres ] || { err "Belum ada hasil build. Jalankan: bash $SCRIPT build"; exit 1; }
    local jobs ram_gb gms
    ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    jobs=${JOBS:-$(( ram_gb / 2 ))}
    [ "$jobs" -gt "$(nproc)" ] && jobs=$(nproc)
    [ "$jobs" -lt 2 ] && jobs=2
    SIGN=1
    gms=$(cat .gms-ingres 2>/dev/null || echo true)
    set +u
    # shellcheck disable=SC1091
    source build/envsetup.sh >/dev/null
    export WITH_GMS="$gms"
    [ "$gms" = true ] && export RELAX_USES_LIBRARY_CHECK=true
    if [ "${DECRYPT:-1}" = 0 ]; then export TARGET_DECRYPTED_DATA=false; else export TARGET_DECRYPTED_DATA=true; fi
    breakfast ingres "$VARIANT" || { err "breakfast ingres $VARIANT gagal"; exit 1; }
    package_variant "$gms" "$jobs"
    ls -lh "$HASIL_DIR"
    if [ "${GOFILE:-1}" != 0 ]; then do_upload || echo "Upload GoFile gagal. Ulangi: bash $SCRIPT upload"; fi
}

# Build satu varian: $1 = true (GApps) / false (vanilla), $2 = jumlah job
build_variant() {
    local gms="$1" jobs="$2" rc vstart name
    vstart=$(date +%s)
    export WITH_GMS="$gms"
    if [ "$gms" = true ]; then
        name="GApps"
        export RELAX_USES_LIBRARY_CHECK=true   # APK Google punya uses-library opsional
    else
        name="vanilla (tanpa GApps)"
        unset RELAX_USES_LIBRARY_CHECK
    fi
    info "Build $name"
    breakfast ingres "$VARIANT" || { err "breakfast ingres $VARIANT gagal (cek local manifest / sync)"; exit 1; }
    # GApps <-> vanilla: file GApps lama masih tertinggal di out/ -> installclean
    if [ -f .gms-ingres ] && [ "$(cat .gms-ingres)" != "$gms" ]; then
        info "Varian GApps berganti: installclean dulu"
        m installclean >/dev/null 2>&1 || true
    fi
    echo "$gms" > .gms-ingres
    m bacon -j"$jobs" 2>&1 | tee "$LOG"
    rc=${PIPESTATUS[0]}
    echo "Durasi $name: $(( ($(date +%s) - vstart) / 60 )) menit"

    if [ "$rc" -ne 0 ]; then
        err "Build gagal. Ini penyebabnya (kirim screenshot bagian ini):"
        echo "------------------------------------------------------------"
        # baris progres "[ 23% ...]" berisi nama modul (mis. libthiserror) -> buang
        { grep -n -A12 '^FAILED: ' "$LOG" | grep -v -E '^[0-9]+[-:]\[ *[0-9]+% ' | head -n 40
          grep -n -E '(^|[^a-z_])(error|e): |ninja: build stopped' "$LOG" | grep -v -E 'warning:|^[0-9]+:\[ *[0-9]+% ' | tail -n 15
        } | grep . || tail -n 60 "$LOG"
        # error Python (mis. saat membuat zip OTA) ada di Traceback-nya
        if grep -q 'Traceback (most recent call last)' "$LOG"; then
            echo "------------------------------------------------------------"
            grep -n -A30 'Traceback (most recent call last)' "$LOG" | tail -n 40
        fi
        echo "------------------------------------------------------------"
        echo "Setelah source ditambal, lanjutkan dengan: bash $SCRIPT build"
        exit 1
    fi

    package_variant "$gms" "$jobs"
}

# ------------------------------------------------------------- GoFile
gofile_put() {   # $1=file $2=folderId(opsional) $3=token(opsional) -> JSON
    local args=(-sS --retry 3 --retry-delay 10 -F "file=@$1")
    [ -n "$2" ] && args+=(-F "folderId=$2")
    [ -n "$3" ] && args+=(-H "Authorization: Bearer $3")
    curl "${args[@]}" https://upload.gofile.io/uploadfile
}

is_ok() {         # JSON di stdin berstatus ok?
    python3 -c "import json,sys
try: sys.exit(0 if json.load(sys.stdin).get('status')=='ok' else 1)
except Exception: sys.exit(1)"
}

json_get() {     # $1=key -> nilai dari JSON di stdin (data.<key>)
    python3 -c "import json,sys
try: print(json.load(sys.stdin).get('data',{}).get('$1',''))
except Exception: pass"
}

do_upload() {
    local files=() f resp link folder token="${GOFILE_TOKEN:-}" linkfile="$HASIL_DIR/link-gofile.txt"
    for f in "$HASIL_DIR"/*.zip "$HASIL_DIR"/*.sha256 "$HASIL_DIR"/*.img; do
        [ -f "$f" ] && files+=("$f")
    done
    [ ${#files[@]} -gt 0 ] || { err "Tidak ada file di $HASIL_DIR untuk diupload"; return 1; }
    info "Upload ${#files[@]} file ke GoFile (zip ROM paling lama, sabar)"
    folder=""; link=""
    : > "$linkfile"
    for f in "${files[@]}"; do
        info "Upload $(basename "$f") ($(du -h "$f" | cut -f1))"
        resp=$(gofile_put "$f" "$folder" "$token")
        if ! echo "$resp" | is_ok; then
            # coba sekali lagi sebagai file terpisah
            resp=$(gofile_put "$f" "" "${GOFILE_TOKEN:-}")
        fi
        if echo "$resp" | is_ok; then
            [ -n "$folder" ] || folder=$(echo "$resp" | json_get parentFolder)
            [ -n "$token" ] || token=$(echo "$resp" | json_get guestToken)
            local page; page=$(echo "$resp" | json_get downloadPage)
            [ -n "$link" ] || link="$page"
            echo "$(basename "$f")  $page" >> "$linkfile"
        else
            err "Gagal upload $(basename "$f"): $(echo "$resp" | head -c 200)"
            echo "$(basename "$f")  GAGAL" >> "$linkfile"
        fi
    done
    echo
    ok "Link GoFile (buka di browser HP untuk download):"
    cat "$linkfile"
    echo "Link juga tersimpan di $linkfile"
}

# ------------------------------------------------------------------ main
case "$CMD" in
    all)   check_tools; do_sync; do_build ;;
    sync)  check_tools; do_sync ;;
    build) check_tools; do_build ;;
    upload) do_upload ;;
    keys)  do_keys ;;
    sign)  check_tools; do_sign ;;
    reset-ingres)
        cd "$SRC" 2>/dev/null || { err "Folder $SRC tidak ada"; exit 1; }
        for d in device/xiaomi/ingres device/xiaomi/sm8450-common hardware/xiaomi \
                 vendor/xiaomi/ingres vendor/xiaomi/sm8450-common \
                 kernel/xiaomi/sm8450 kernel/xiaomi/sm8450-modules kernel/xiaomi/sm8450-devicetrees; do
            info "Menghapus $d"
            rm -rf "${SRC:?}/$d" "${SRC:?}/.repo/projects/$d.git"
        done
        ok "Selesai. Lanjutkan dengan: bash $SCRIPT"
        ;;
    clean)
        info "Menghapus $SRC/out dan $HASIL_DIR"
        rm -rf "${SRC:?}/out" "$HASIL_DIR"
        ok "Bersih. Ruang disk kosong: $(df -h --output=avail "$HOME" | tail -n 1)"
        ;;
    *) err "Perintah tidak dikenal: $CMD (pakai: all | sync | build | upload | clean | status | bersih | reset-ingres | keys | sign)"; exit 1 ;;
esac
