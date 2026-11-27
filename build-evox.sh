#!/usr/bin/env bash
#
# Build Evolution X 12.4 (cnb, Android 17) untuk POCO F4 GT (ingres) - satu perintah.
#
#   bash build-evox.sh            # sync + build (otomatis jalan di byobu)
#   bash build-evox.sh sync       # hanya sync source
#   bash build-evox.sh build      # hanya build (lanjut dari build sebelumnya)
#   bash build-evox.sh status     # lihat progres build yang sedang jalan
#   bash build-evox.sh upload     # upload ulang isi ~/hasil-evox ke GoFile
#   bash build-evox.sh clean      # hapus hasil build lama (out/) lalu berhenti
#   bash build-evox.sh bersih ~/aospa   # hapus source ROM lain / folder lama
#   bash build-evox.sh reset-ingres     # hapus repo ingres/xiaomi lama lalu sync ulang
#
# Pengaturan (opsional, isi sebelum perintah, contoh: GAPPS=0 bash build-evox.sh):
#   SRC=~/evox         folder source
#   JOBS=<angka>       jumlah job build (default: otomatis dari CPU & RAM)
#   VARIANT=user       user (rilis, default) / userdebug / eng
#   GAPPS=1            build dengan GApps (default)
#   GAPPS=0            build vanilla tanpa GApps
#   GAPPS=both         build dua-duanya berurutan (GApps lalu vanilla)
#   PIXEL_LAUNCHER=1   build GApps tetap pakai Pixel Launcher (default: Launcher3,
#                      supaya fitur geser ke atas -> gelembung aplikasi ikut)
#   DECRYPT=0          /data terenkripsi seperti biasa (default: decrypt)
#   DV_TMAX=800        batas terang Dolby Vision (nit) layar F4 GT (0 = setelan asli Sony)
#   AOD_FADE_MS=500    lama AOD memudar sebelum layar mati, ms (0 = tanpa, perilaku asli)
#   SIGN=0             kunci bawaan ROM (default: tanda tangan kingD2N = kunci LineageOS, ~/.ingres-keys)
#   GOFILE=0           jangan upload hasil ke GoFile (default: upload otomatis)
#   GOFILE_TOKEN=xxx   token akun GoFile (opsional)

set -uo pipefail

ROM=evox
ROM_NAME="Evolution X 12.4"
ROM_MANIFEST="https://github.com/Evolution-X/manifest"; ROM_BRANCH="cnb"
SRC="${SRC:-$HOME/evox}"
VARIANT="${VARIANT:-user}"
SESSION="evox"
LOG="$HOME/build-evox.log"
MANIFEST_URL="https://raw.githubusercontent.com/kingD2N/android_device_xiaomi_ingres-old/evox-cnb/local_manifests/evox.xml"
HASIL_DIR="$HOME/hasil-evox"
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
    for d in "$HOME/los24" "$HOME/lunaris" "$HOME/hasil-lunaris" "$HOME/build-lunaris.log" "$HOME/lunaris-sisa-lama" \
             "$HOME/uwu" "$HOME/infinity" "$HOME/ascp" "$HOME/aospa" "$HOME/axion" "$HOME/penguin" \
             "$HOME/.ccache" "$@"; do
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
    echo "Simpan dulu zip ROM lama (mis. ~/hasil-lunaris) lewat SFTP kalau masih perlu."
    read -r -p "Ketik YA lalu Enter untuk menghapus: " jawab
    [ "$jawab" = "YA" ] || { info "Batal, tidak ada yang dihapus."; exit 0; }
    for s in los24 aospa lunaris uwu infinity ascp evox; do
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
if [ -z "${TMUX:-}" ] && [ -z "${STY:-}" ] && [ "$CMD" != "clean" ] && [ "$CMD" != "reset-ingres" ]; then
    command -v byobu >/dev/null || { err "byobu tidak ada di server"; exit 1; }
    if byobu ls 2>/dev/null | grep -q "^$SESSION"; then
        err "Sesi '$SESSION' sudah ada (satu build per akun). Masuk dengan: byobu attach -t $SESSION"
        exit 1
    fi
    envs="SRC='$SRC' VARIANT='$VARIANT' GAPPS='${GAPPS:-1}' PIXEL_LAUNCHER='${PIXEL_LAUNCHER:-0}' GOOGLE_INSTALLER='${GOOGLE_INSTALLER:-0}' DECRYPT='${DECRYPT:-1}' SIGN='${SIGN:-1}' KEYS_DIR='${KEYS_DIR:-}' AOD_FADE_MS='${AOD_FADE_MS:-500}' DV_TMAX='${DV_TMAX:-800}' GOFILE='${GOFILE:-1}' GOFILE_TOKEN='${GOFILE_TOKEN:-}' JOBS='${JOBS:-}'"
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
    # Kalau ~/.gitconfig tidak terbaca (profil server), repo init gagal "Committer identity unknown".
    # Variabel ini selalu dipakai git, apa pun isi config-nya.
    export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-$(git config --global user.name 2>/dev/null || echo kingD2N)}"
    export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-$(git config --global user.email 2>/dev/null || echo 114895723+kingD2N@users.noreply.github.com)}"
    export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-$GIT_AUTHOR_NAME}" GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$GIT_AUTHOR_EMAIL}"
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
    local known d bak="$HOME/evox-sisa-lama"
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
    local known d bak="$HOME/evox-sisa-lama"
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

# Launcher3: geser ke atas dari aplikasi melewati batas (ada getar), lepas -> aplikasi
# dibuka sebagai gelembung (bubble). Pengaturan ada di Setelan Layar utama.
# Patch disimpan di device tree.
L3_DIR=packages/apps/Launcher3
L3_PATCH="$SRC/device/xiaomi/ingres/patches/launcher3/0001-recents-freeform-gesture.patch"
fix_launcher3_freeform() {
    [ -f "$L3_PATCH" ] && [ -f "$L3_DIR/quickstep/src/com/android/quickstep/AbsSwipeUpHandler.java" ] || return 0
    git -C "$L3_DIR" apply --check -R "$L3_PATCH" 2>/dev/null && return 0   # sudah terpasang
    if git -C "$L3_DIR" apply "$L3_PATCH"; then
        info "Tambalan: Launcher3 geser ke atas -> gelembung aplikasi"
    else
        err "Tambalan Launcher3 gelembung tidak cocok lagi (Launcher3 berubah), dilewati"
    fi
}

# Build GApps EvoX memasang Pixel Launcher (APK prebuilt) yang menimpa Launcher3,
# jadi fitur Launcher3 di atas tidak ikut. Default: Pixel Launcher dibuang dan
# overlay Pixel (recents/home) diarahkan balik ke Launcher3. PIXEL_LAUNCHER=1 = tetap.
# Overlay dicari dari ISI-nya, bukan dari nama foldernya: EvoX pernah mengganti nama
# PixelConfigOverlayCommon jadi PixelConfigOverlayCommonGMS tanpa kabar, tambalan diam-diam
# tidak kena, dan Launcher3 crash terus karena recents menunjuk ke Pixel Launcher yang dibuang.
PIXEL_SCAN_DIRS="vendor/pixel-style vendor/gms vendor/evolution"
PIXEL_RECENTS_RE='name="config_(recentsComponentName|secondaryHomePackage)">com\.google\.android\.apps\.nexuslauncher'
GMS_NEXUS_RE='^[[:space:]]*NexusLauncherRelease[[:space:]]*\\$'
# file xml yang masih mengarahkan recents/home ke Pixel Launcher
pixel_launcher_refs() {
    local d dirs=""
    for d in $PIXEL_SCAN_DIRS; do [ -d "$d" ] && dirs="$dirs $d"; done
    [ -n "$dirs" ] || return 0
    grep -rlIE --include='*.xml' "$PIXEL_RECENTS_RE" $dirs 2>/dev/null || true
}
fix_pixel_launcher() {
    [ "${PIXEL_LAUNCHER:-0}" = 1 ] && return 0
    [ -d vendor/gms ] || return 0
    local f changed=0
    for f in vendor/gms/gms*.mk; do
        [ -f "$f" ] || continue
        if grep -q "$GMS_NEXUS_RE" "$f"; then
            sed -i "/$GMS_NEXUS_RE/d" "$f"
            changed=1
        fi
    done
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        sed -i \
            -e 's|\(name="config_recentsComponentName">\)com\.google\.android\.apps\.nexuslauncher/|\1com.android.launcher3/|' \
            -e 's|\(name="config_secondaryHomePackage">\)com\.google\.android\.apps\.nexuslauncher<|\1com.android.launcher3<|' \
            "$f"
        changed=1
    done < <(pixel_launcher_refs)
    [ $changed = 1 ] && info "Tambalan: Pixel Launcher dibuang, GApps pakai Launcher3 (PIXEL_LAUNCHER=1 untuk tetap)"
    return 0
}
# Pengaman: kalau setelah ditambal recents/home masih menunjuk ke Pixel Launcher, ROM-nya
# pasti bermasalah di launcher. Lebih baik berhenti di sini daripada build berjam-jam.
verify_launcher_overlay() {
    [ "${PIXEL_LAUNCHER:-0}" = 1 ] && return 0
    [ -d vendor/gms ] || return 0
    local left f
    left=$(pixel_launcher_refs)
    if [ -n "$left" ]; then
        err "Recents/home masih menunjuk ke Pixel Launcher setelah ditambal:"
        echo "$left" | sed 's/^/   /' >&2
        err "Launcher3 akan crash. Perbaiki fix_pixel_launcher (struktur overlay EvoX berubah) atau build dengan PIXEL_LAUNCHER=1."
        return 1
    fi
    for f in vendor/gms/gms*.mk; do
        [ -f "$f" ] || continue
        grep -q "$GMS_NEXUS_RE" "$f" && info "Peringatan: $f masih memasang NexusLauncherRelease (Pixel Launcher ikut terpasang)"
    done
    return 0
}

# vendor/gms (16/11/2026) memasukkan lagi AmbientStreaming, tapi APK-nya tidak
# terdaftar di .gitattributes, jadi yang ter-checkout cuma pointer Git LFS (130 byte)
# dan build GApps gagal. Unduh isinya lewat git lfs; kalau gagal, lewati aplikasinya.
AMBIENT_DIR=vendor/gms/product/packages/privileged_apps/AmbientStreaming
fix_ambient_streaming() {
    local apk=product/packages/privileged_apps/AmbientStreaming/AmbientStreaming.apk
    [ -f "vendor/gms/$apk" ] || return 0
    if head -c 40 "vendor/gms/$apk" | grep -q '^version https://git-lfs'; then
        if (cd vendor/gms && git lfs smudge "$apk" < "$apk" > "$apk.lfs") 2>/dev/null \
                && [ "$(head -c 2 "vendor/gms/$apk.lfs")" = PK ]; then
            mv -f "vendor/gms/$apk.lfs" "vendor/gms/$apk"
            info "Tambalan: AmbientStreaming.apk diunduh dari LFS (vendor/gms cuma berisi pointer)"
        else
            rm -f "vendor/gms/$apk.lfs"
            sed -i '/^[[:space:]]*AmbientStreaming[[:space:]]*\\$/d' vendor/gms/gms*.mk
            info "Tambalan: AmbientStreaming dilewati (APK dari LFS tidak bisa diunduh)"
            return 0
        fi
    fi
    grep -q 'LOCAL_ENFORCE_USES_LIBRARIES' "$AMBIENT_DIR/Android.mk" 2>/dev/null && return 0
    sed -i 's|^include \$(BUILD_PREBUILT)|LOCAL_ENFORCE_USES_LIBRARIES := false\n&|' "$AMBIENT_DIR/Android.mk"
}

# PackageInstaller: tampilan pemasang aplikasi Lunaris (Compose Material 3 Expressive,
# port dari Lunaris-AOSP/frameworks_base 16.2). Gaya bisa diganti tanpa build ulang:
#   settings put secure package_installer_style 2   (0 = AOSP, 1 = dialog, 2 = bottom sheet)
# Build GApps memasang GooglePackageInstaller (APK prebuilt) yang menimpa PackageInstaller,
# jadi APK itu dibuang dari vendor/gms. GOOGLE_INSTALLER=1 = tetap pakai pemasang Google.
PI_PATCH="$SRC/device/xiaomi/ingres/patches/frameworks_base/0001-PackageInstaller-Lunaris-expressive-UI.patch"
fix_package_installer() {
    [ -f "$PI_PATCH" ] && [ -d frameworks/base/packages/PackageInstaller ] || return 0
    if git -C frameworks/base apply --check -R "$PI_PATCH" 2>/dev/null; then   # sudah terpasang
        drop_google_installer
        return 0
    fi
    if git -C frameworks/base apply "$PI_PATCH"; then
        info "Tambalan: PackageInstaller tampilan Lunaris"
    else
        err "Tambalan PackageInstaller Lunaris tidak cocok lagi (frameworks/base EvoX berubah), dilewati"
        return 0
    fi
    drop_google_installer
}
drop_google_installer() {
    [ "${GOOGLE_INSTALLER:-0}" = 1 ] && return 0
    local f changed=0
    for f in vendor/gms/gms*.mk; do
        [ -f "$f" ] || continue
        if grep -q '^[[:space:]]*GooglePackageInstaller[[:space:]]*\\$' "$f"; then
            sed -i '/^[[:space:]]*GooglePackageInstaller[[:space:]]*\\$/d' "$f"
            changed=1
        fi
    done
    [ $changed = 1 ] && info "Tambalan: GooglePackageInstaller dibuang, GApps pakai PackageInstaller Lunaris"
    return 0
}

unpatch_source() {
    unpatch_dv_cfg
    unpatch_aod_fade
    unpatch_signing
    if [ -f "$PI_PATCH" ] && git -C frameworks/base apply --check -R "$PI_PATCH" 2>/dev/null; then
        git -C frameworks/base apply -R "$PI_PATCH" || true
    fi
    git -C vendor/gms checkout -q -- 'gms*.mk' product/packages/privileged_apps/AmbientStreaming 2>/dev/null || true
    local d
    for d in $PIXEL_SCAN_DIRS; do
        git -C "$d" checkout -q -- '*.xml' 2>/dev/null || true
    done
    git -C hardware/qcom-caf/sm8450/display checkout -q -- composer/hwc_display.cpp 2>/dev/null || true
    git -C vendor/xiaomi/gamekey checkout -q -- third_party/rust daemon/src 2>/dev/null || true
    if [ -f "$L3_PATCH" ] && git -C "$L3_DIR" apply --check -R "$L3_PATCH" 2>/dev/null; then
        git -C "$L3_DIR" apply -R "$L3_PATCH" || true
    fi
}
# AOD memudar halus sebelum layar mati (gaya HyperOS), mis. saat batas waktu/jadwal AOD habis.
# Sama dengan tambalan AxionOS yang sudah diuji; dilewati otomatis bila source ROM berbeda.
# AOSP: ScrimState.OFF tidak beranimasi bila asalnya AOD, dan AOD memakai DOZE_SUSPEND
# (layar membeku) sehingga animasi tidak tergambar. Tambalan: layar dipindah ke DOZE selama
# pemudaran (wakelock dipegang), scrim memudar AOD_FADE_MS, lalu layar OFF.
# AOD_FADE_MS=0 = tanpa tambalan (perilaku asli).
AOD_FADE_MS="${AOD_FADE_MS:-500}"
AOD_SCRIM=frameworks/base/packages/SystemUI/src/com/android/systemui/statusbar/phone/ScrimState.java
AOD_DSS=frameworks/base/packages/SystemUI/src/com/android/systemui/doze/DozeScreenState.java
unpatch_aod_fade() {
    git -C frameworks/base checkout -q -- "${AOD_SCRIM#frameworks/base/}" "${AOD_DSS#frameworks/base/}" 2>/dev/null || true
}
fix_aod_fade() {
    case "$AOD_FADE_MS" in ''|*[!0-9]*) err "AOD_FADE_MS harus angka (ms)"; return 0 ;; esac
    [ "$AOD_FADE_MS" -gt 0 ] || return 0
    [ -d frameworks/base/packages/SystemUI ] || return 0   # source belum disinkron
    [ -f "$AOD_SCRIM" ] && [ -f "$AOD_DSS" ] || { err "AOD halus: file SystemUI tidak ditemukan, dilewati"; return 0; }
    unpatch_aod_fade
    if python3 - "$AOD_SCRIM" "$AOD_DSS" "$AOD_FADE_MS" <<'PY'
import sys
scrim, dss, ms = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(scrim).read()
old = """            if (previousState == AOD) {
                mAnimateChange = false;
            } else {
                mAnimationDuration = ScrimController.ANIMATION_DURATION_LONG;
            }"""
new = """            // ingres: AOD memudar halus sebelum layar mati
            mAnimateChange = true;
            if (previousState == AOD) {
                mAnimationDuration = %s;
            } else {
                mAnimationDuration = ScrimController.ANIMATION_DURATION_LONG;
            }""" % ms
if s.count(old) != 1: sys.exit("ScrimState.OFF tidak cocok")
open(scrim, "w").write(s.replace(old, new))
d = open(dss).read()
reps = [
 ("    private SettableWakeLock mWakeLock;\n",
  "    private SettableWakeLock mWakeLock;\n    private SettableWakeLock mFadeWakeLock;\n"),
 ("        mWakeLock = new SettableWakeLock(wakeLock, TAG);\n",
  "        mWakeLock = new SettableWakeLock(wakeLock, TAG);\n        mFadeWakeLock = new SettableWakeLock(wakeLock, TAG + \"Fade\");\n"),
 ("        mDozeHost.cancelGentleSleep();\n",
  "        mDozeHost.cancelGentleSleep();\n        mFadeWakeLock.setAcquired(false);\n"),
 ("""            } else {
                mDozeHost.prepareForGentleSleep(() -> applyScreenState(screenState));
            }""",
  """            } else if (oldState == DOZE_AOD && newState == DOZE) {
                // ingres: DOZE_SUSPEND membekukan layar; pindah ke DOZE agar pemudaran AOD
                // tergambar, lalu matikan layar setelah scrim selesai memudar.
                applyScreenState(Display.STATE_DOZE);
                mFadeWakeLock.setAcquired(true);
                mDozeHost.prepareForGentleSleep(() -> {
                    applyScreenState(screenState);
                    mFadeWakeLock.setAcquired(false);
                });
            } else {
                mDozeHost.prepareForGentleSleep(() -> applyScreenState(screenState));
            }"""),
]
for o, n in reps:
    if d.count(o) != 1: sys.exit("DozeScreenState tidak cocok: " + o.strip()[:50])
    d = d.replace(o, n)
open(dss, "w").write(d)
PY
    then
        info "Tambalan: AOD memudar halus ${AOD_FADE_MS} ms sebelum layar mati"
    else
        unpatch_aod_fade
        err "AOD halus: source SystemUI berubah, tambalan dilewati (ROM tetap bisa di-build)"
    fi
    return 0
}
# Dolby Vision: setelan layar POCO F4 GT. dolby_vision.cfg bawaan hardware/dolby berasal dari panel
# Sony (Tmax 589.6 nit, warna panel Sony) sehingga konten HDR tinggi diredupkan berlebihan.
# Diganti batas layar F4 GT: AMOLED 800 nit (HBM), hitam ~0, gamut DCI-P3 (diuji di HP 25/11/2026).
DV_TMAX="${DV_TMAX:-800}"
DV_CFG=hardware/dolby/proprietary/vendor/etc/dolby_vision.cfg
unpatch_dv_cfg() {
    [ -d hardware/dolby/.git ] || [ -f hardware/dolby/.git ] || return 0
    git -C hardware/dolby checkout -q -- proprietary/vendor/etc/dolby_vision.cfg 2>/dev/null
    return 0
}
fix_dv_cfg() {
    [ -f "$DV_CFG" ] || return 0
    [ "$DV_TMAX" = 0 ] && return 0
    sed -i -e "s/^Tmax = .*/Tmax = $DV_TMAX/" \
        -e 's/^Tmin = .*/Tmin = 0.005/' \
        -e 's/^TPrimaries = .*/TPrimaries = 0.680 0.320 0.265 0.690 0.150 0.060 0.3127 0.3290/' "$DV_CFG"
    grep -q "^Tmax = $DV_TMAX\$" "$DV_CFG" && info "Tambalan: Dolby Vision memakai batas layar POCO F4 GT ($DV_TMAX nit, DCI-P3)"
    return 0
}
patch_source() {
    fix_dv_cfg
    fix_aod_fade
    fix_dolby_vision
    fix_gamekey
    fix_launcher3_freeform
    fix_package_installer
    fix_pixel_launcher
    fix_ambient_streaming
}

# ------------------------------------------------------------------ sync
do_sync() {
    # aturan server: maksimal 2 source ROM per akun (termasuk ROM ini)
    local other others="" n_other=0
    for other in "$HOME"/*/.repo; do
        [ -d "$other" ] || continue
        other="$(dirname "$other")"
        [ "$(readlink -f "$other")" = "$(readlink -f "$SRC")" ] && continue
        others="$others $other"
        n_other=$((n_other + 1))
    done
    if [ "$n_other" -ge 2 ]; then
        err "Sudah ada $n_other source ROM lain:$others (server maksimal 2 source ROM)."
        echo "   Simpan dulu zip-nya kalau perlu, lalu hapus salah satu: bash $SCRIPT bersih <folder>"
        exit 1
    fi
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
        [ -e "$f" ] && [ "$(basename "$f")" != evox.xml ] && mv -f "$f" "$f.bak" && info "Menyingkirkan $(basename "$f")"
    done
    curl -fsSL -o .repo/local_manifests/evox.xml "$MANIFEST_URL?$(date +%s)" || { err "Gagal unduh local manifest"; exit 1; }

    # sisa percobaan lama: folder ingres/xiaomi yang bukan hasil repo ini bikin
    # "unsupported checkout state" dan Android.bp lama (vendor common salah versi)
    reset_project() {
        local rel="${1#"$SRC"/}"; rel="${rel%/.git}"; rel="${rel%/}"
        case "$rel" in ""|/*|*..*) return ;; esac
        info "Menghapus checkout lama: $rel"
        rm -rf "${SRC:?}/$rel" "${SRC:?}/.repo/projects/$rel.git"
    }

    unpatch_source
    local n slog="$HOME/sync-evox.log"
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
    verify_launcher_overlay || err "Periksa tambalan launcher sebelum build"
    ok "Source siap di $SRC"
}

# Header kernel hasil generate (generated_kernel_includes) hanya dibuat ulang kalau
# Makefile/include kernel berubah. Kalau header UAPI vendor (audio/display) tidak
# lengkap, hapus supaya dibuat ulang dari kernel yang sekarang.
fix_kernel_headers() {
    local g=out/soong/.intermediates/vendor/lineage/build/soong/generated_kernel_includes
    [ -d "$g" ] || return 0
    if [ -z "$(find "$g" -path '*usr/include/display/drm/sde_drm.h' -print -quit 2>/dev/null)" ] \
        || [ -z "$(find "$g" -path '*usr/include/audio/linux/msm_audio.h' -print -quit 2>/dev/null)" ]; then
        info "Header kernel tidak lengkap, dibuat ulang"
        rm -rf "$g"
    fi
}

# ---------------------------------------------- tanda tangan kingD2N
# Semua ROM ingres ditandatangani kunci pribadi yang sama dengan LineageOS 24 (~/.ingres-keys).
# Kunci dibuat sekali (oleh ROM mana pun yang dibuild pertama) lalu dipakai ulang semua ROM.
# Kunci dipasang ke folder kunci yang dibaca ROM itu (vendor/<rom>-priv/keys); ROM tanpa
# folder seperti itu mendapat -include di device.mk. SIGN=0 = pakai kunci bawaan ROM.
SIGN_KEYS_DIR="${KEYS_DIR:-$HOME/.ingres-keys}"
SIGN_KEY_NAMES="releasekey platform shared media networkstack sdk_sandbox bluetooth nfc verity testkey cyngn-app testcert"
SIGN_SUBJECT="/C=ID/ST=Indonesia/L=Indonesia/O=kingD2N/OU=kingD2N/CN=kingD2N"
SIGN_MARK="# ingres-sign"
SIGN_DEVMK=device/xiaomi/ingres/device.mk
sign_make_key() {   # $1 = nama kunci (dibuat di $SIGN_KEYS_DIR, tanpa password)
    local k="$1" t top="$PWD"
    if [ -x "$top/development/tools/make_key" ]; then
        # make_key menolak path bertitik (".ingres-keys"): jalankan dari dalam folder kunci
        (cd "$SIGN_KEYS_DIR" && echo | "$top/development/tools/make_key" "$k" "$SIGN_SUBJECT") >/dev/null 2>&1
    fi
    if ! [ -s "$SIGN_KEYS_DIR/$k.pk8" ] && command -v openssl >/dev/null 2>&1; then
        rm -f "$SIGN_KEYS_DIR/$k.pk8" "$SIGN_KEYS_DIR/$k.x509.pem"
        t=$(mktemp "$SIGN_KEYS_DIR/tmp.XXXXXX") || return 1
        openssl genrsa -f4 2048 2>/dev/null > "$t" \
            && openssl req -new -x509 -sha256 -key "$t" -out "$SIGN_KEYS_DIR/$k.x509.pem" \
                   -days 10000 -subj "$SIGN_SUBJECT" 2>/dev/null \
            && openssl pkcs8 -in "$t" -topk8 -outform DER -out "$SIGN_KEYS_DIR/$k.pk8" -nocrypt 2>/dev/null
        rm -f "$t"
    fi
    [ -s "$SIGN_KEYS_DIR/$k.pk8" ] && [ -s "$SIGN_KEYS_DIR/$k.x509.pem" ]
}
sign_priv_dir() {   # folder kunci yang dibaca konfigurasi ROM, mis. vendor/lineage-priv/keys
    grep -rhoE 'vendor/[A-Za-z0-9_.-]+-priv/keys' vendor/*/config vendor/*/*.mk 2>/dev/null \
        | sort | uniq -c | sort -rn | awk 'NR==1 {print $2}' || true
}
unpatch_signing() {
    [ -f "$SIGN_DEVMK" ] && sed -i "/$SIGN_MARK\$/d" "$SIGN_DEVMK"
    return 0
}
setup_signing() {
    local priv k made=0 viadev=""
    unpatch_signing
    if [ "${SIGN:-1}" = 0 ]; then
        for priv in vendor/*-priv/keys; do
            [ -f "$priv/.ingres-sign" ] && rm -rf "$priv"
        done
        info "Tanda tangan: kunci bawaan ROM (SIGN=0)"
        return 0
    fi
    mkdir -p "$SIGN_KEYS_DIR" && chmod 700 "$SIGN_KEYS_DIR"
    for k in $SIGN_KEY_NAMES; do
        [ -s "$SIGN_KEYS_DIR/$k.pk8" ] && [ -s "$SIGN_KEYS_DIR/$k.x509.pem" ] && continue
        sign_make_key "$k" || { err "Gagal membuat kunci $k, ROM memakai kunci bawaan"; return 0; }
        made=$((made + 1))
    done
    chmod 600 "$SIGN_KEYS_DIR"/* 2>/dev/null || true
    priv=$(sign_priv_dir)
    if [ -z "$priv" ]; then
        [ -f "$SIGN_DEVMK" ] || { err "Tanda tangan: $SIGN_DEVMK tidak ada, ROM memakai kunci bawaan"; return 0; }
        priv=vendor/ingres-priv/keys; viadev=1
    fi
    rm -rf "$priv" && mkdir -p "$priv"
    for k in $SIGN_KEY_NAMES; do
        cp -f "$SIGN_KEYS_DIR/$k.pk8" "$SIGN_KEYS_DIR/$k.x509.pem" "$priv/"
    done
    echo "PRODUCT_DEFAULT_DEV_CERTIFICATE := $priv/releasekey" > "$priv/keys.mk"
    cat > "$priv/BUILD.bazel" <<'BZL'
filegroup(
    name = "android_certificate_directory",
    srcs = glob([
        "*.pk8",
        "*.pem",
    ]),
    visibility = ["//visibility:public"],
)
BZL
    : > "$priv/.ingres-sign"
    if [ -n "$viadev" ]; then
        sed -i -e '$a\' "$SIGN_DEVMK"
        echo "-include $priv/keys.mk $SIGN_MARK" >> "$SIGN_DEVMK"
    fi
    [ "$made" -gt 0 ] && info "Tanda tangan: $made kunci baru dibuat di $SIGN_KEYS_DIR (backup folder ini!)"
    info "Tanda tangan kingD2N: kunci $SIGN_KEYS_DIR -> $priv${viadev:+ (lewat device.mk)}"
    return 0
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
    setup_signing
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

# Build satu varian: $1 = true (GApps) / false (vanilla), $2 = jumlah job
build_variant() {
    local gms="$1" jobs="$2" rc vstart name
    vstart=$(date +%s)
    export WITH_GMS="$gms"
    if [ "$gms" = true ]; then name="GApps"; else name="vanilla (tanpa GApps)"; fi
    info "Build $name"
    lunch "lineage_ingres-cp2a-$VARIANT" || { err "lunch lineage_ingres-cp2a-$VARIANT gagal (cek local manifest / sync)"; exit 1; }
    # GApps <-> vanilla: file GApps lama masih tertinggal di out/ -> installclean
    if [ -f .gms-ingres ] && [ "$(cat .gms-ingres)" != "$gms" ]; then
        info "Varian GApps berganti: installclean dulu"
        m installclean >/dev/null 2>&1 || true
    fi
    echo "$gms" > .gms-ingres
    m evolution -j"$jobs" 2>&1 | tee "$LOG"
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

    local p="out/target/product/ingres" zip
    if [ "$gms" = true ]; then
        zip=$(ls -t "$p"/EvolutionX-*-ingres-*.zip 2>/dev/null | grep -v -e '-Vanilla-' -e target_files | head -n 1)
    else
        zip=$(ls -t "$p"/EvolutionX-*-ingres-*-Vanilla-*.zip 2>/dev/null | head -n 1)
    fi
    [ -n "$zip" ] || { err "Build selesai tapi zip tidak ditemukan"; exit 1; }
    cp "$zip" $p/boot.img $p/dtbo.img $p/vendor_boot.img $p/recovery.img "$HASIL_DIR"/ 2>/dev/null
    (cd "$HASIL_DIR" && sha256sum "$(basename "$zip")" > "$(basename "$zip").sha256")
    ok "Selesai: $(basename "$zip")"
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
    *) err "Perintah tidak dikenal: $CMD (pakai: all | sync | build | upload | clean | status | bersih | reset-ingres)"; exit 1 ;;
esac
