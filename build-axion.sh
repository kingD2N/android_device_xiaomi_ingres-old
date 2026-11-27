#!/usr/bin/env bash
#
# Build AxionOS terbaru (branch lineage-23.2, Android 16 QPR2) untuk
# POCO F4 GT (ingres) - satu perintah.
#
#   bash build-axion.sh            # sync + build (otomatis jalan di byobu)
#   bash build-axion.sh sync       # hanya sync source
#   bash build-axion.sh build      # hanya build (lanjut dari build sebelumnya)
#   bash build-axion.sh status     # lihat progres build yang sedang jalan
#   bash build-axion.sh upload     # upload ulang isi ~/hasil-axion ke GoFile
#   bash build-axion.sh clean      # hapus hasil build lama (out/) lalu berhenti
#   bash build-axion.sh bersih ~/lunaris # hapus source ROM lain / folder lama
#   bash build-axion.sh reset-ingres     # hapus repo ingres/xiaomi lama lalu sync ulang
#
# Pengaturan (opsional, isi sebelum perintah, contoh: GAPPS=0 bash build-axion.sh):
#   SRC=~/axion        folder source
#   JOBS=<angka>       jumlah job build (default: otomatis dari CPU & RAM)
#   VARIANT=user       user (rilis, default) / userdebug / eng
#   GAPPS=gms          GApps lengkap (default)
#   GAPPS=pico         GApps minimal / GAPPS=core  GApps inti / GAPPS=0  vanilla
#   DECRYPT=0          /data terenkripsi seperti biasa (default: decrypt)
#   DV_TMAX=800        batas terang Dolby Vision (nit) layar F4 GT (0 = setelan asli Sony)
#   SIGN=0             kunci acak AxionOS lama (default: kunci kingD2N yang sama dgn LineageOS, ~/.ingres-keys)
#   AOD_FADE_MS=500    lama AOD memudar sebelum layar mati, ms (0 = tanpa, perilaku asli)
#   GOFILE=0           jangan upload hasil ke GoFile (default: upload otomatis)
#   GOFILE_TOKEN=xxx   token akun GoFile (opsional)

set -uo pipefail

ROM=axion
ROM_NAME="AxionOS (lineage-23.2)"
ROM_MANIFEST="https://github.com/AxionAOSP/android"; ROM_BRANCH="lineage-23.2"
SRC="${SRC:-$HOME/axion}"
VARIANT="${VARIANT:-user}"
SESSION="axion"
LOG="$HOME/build-axion.log"
MANIFEST_URL="https://raw.githubusercontent.com/kingD2N/android_device_xiaomi_ingres-old/axion-23.2/local_manifests/axion.xml"
HASIL_DIR="$HOME/hasil-axion"
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
    for d in "$HOME/los24" "$HOME/hasil-los24" "$HOME/build.log" \
             "$HOME/lunaris" "$HOME/hasil-lunaris" "$HOME/build-lunaris.log" \
             "$HOME/axion-sisa-lama" "$HOME/.ccache" "$@"; do
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
    echo "Simpan dulu zip ROM lama (mis. ~/hasil-los24, ~/hasil-lunaris) lewat SFTP kalau masih perlu."
    read -r -p "Ketik YA lalu Enter untuk menghapus: " jawab
    [ "$jawab" = "YA" ] || { info "Batal, tidak ada yang dihapus."; exit 0; }
    for s in los24 aospa lunaris axion; do
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
    envs="SRC='$SRC' VARIANT='$VARIANT' GAPPS='${GAPPS:-gms}' DECRYPT='${DECRYPT:-1}' AOD_FADE_MS='${AOD_FADE_MS:-500}' SIGN='${SIGN:-1}' KEYS_DIR='${KEYS_DIR:-}' DV_TMAX='${DV_TMAX:-800}' GOFILE='${GOFILE:-1}' GOFILE_TOKEN='${GOFILE_TOKEN:-}' JOBS='${JOBS:-}'"
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
    local known d bak="$HOME/axion-sisa-lama"
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
    local known d bak="$HOME/axion-sisa-lama"
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

# Gestur geser ke atas di recents -> buka aplikasi sebagai gelembung (app bubble), seperti
# Pixel Launcher Enhanced. Launcher3 bawaan AxionOS tetap dipakai (hanya ditambal). Aktifkan di
# Pengaturan Launcher > Overview > "Swipe up for app bubble" (jarak geser bisa diatur).
L3_DIR=packages/apps/Launcher3
L3_PATCH="$SRC/device/xiaomi/ingres/patches/launcher3/0001-recents-freeform-gesture.patch"
# Kembalikan berkas yang disentuh sebuah tambalan ke kondisi repo (dipakai kalau versi
# tambalan lama sudah terpasang dan tidak bisa di-reverse lagi dengan tambalan baru).
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
    if ! git -C "$L3_DIR" apply --check -R "$L3_PATCH" 2>/dev/null; then   # belum terpasang
        if ! git -C "$L3_DIR" apply "$L3_PATCH" 2>/dev/null; then
            # mungkin versi tambalan lama masih terpasang: bersihkan lalu pasang ulang
            reset_patch_files "$L3_DIR" "$L3_PATCH"
        fi
        if git -C "$L3_DIR" apply --check -R "$L3_PATCH" 2>/dev/null || git -C "$L3_DIR" apply "$L3_PATCH"; then
            info "Tambalan: Launcher3 geser ke atas -> gelembung aplikasi"
        else
            err "Tambalan Launcher3 gelembung tidak cocok lagi (Launcher3 AxionOS berubah), dilewati"
        fi
    fi
    # GApps yang membawa Pixel Launcher akan menimpa Launcher3 dan gestur ini tidak jalan
    if [ -d vendor/gms ] && grep -rqs 'NexusLauncher' vendor/gms --include=*.mk 2>/dev/null; then
        info "Catatan: vendor/gms memuat Pixel Launcher (NexusLauncher), gestur gelembung hanya jalan di Launcher3"
    fi
}

# Package Installer Style: tampilan pemasangan aplikasi ala Lunaris (dialog / bottom sheet,
# Compose Material3 Expressive; port dari Lunaris-AOSP/frameworks_base 16.2). Blurnya memakai
# ax_blur asli AxionOS (axion_sdk). Gaya bisa diganti tanpa build ulang:
#   settings put secure package_installer_style 2   (0 = AOSP, 1 = dialog, 2 = bottom sheet)
# Kalau GApps membawa GooglePackageInstaller (APK prebuilt), APK itu menimpa PackageInstaller
# dan harus dibuang dari vendor/gms. GOOGLE_INSTALLER=1 = tetap pakai pemasang Google.
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
        err "Tambalan PackageInstaller Lunaris tidak cocok lagi (frameworks/base AxionOS berubah), dilewati"
        return 0
    fi
    drop_google_installer
}
drop_google_installer() {
    [ "${GOOGLE_INSTALLER:-0}" = 1 ] && return 0
    [ -d vendor/gms ] || return 0
    local f changed=0
    while IFS= read -r f; do
        if grep -q '^[[:space:]]*GooglePackageInstaller[[:space:]]*\\$' "$f"; then
            sed -i '/^[[:space:]]*GooglePackageInstaller[[:space:]]*\\$/d' "$f"
            changed=1
        fi
        grep -q '^[[:space:]]*GooglePackageInstaller[[:space:]]*$' "$f" \
            && err "GooglePackageInstaller di $f tanpa backslash: tidak dibuang otomatis"
    done < <(find vendor/gms -maxdepth 3 -name '*.mk' 2>/dev/null)
    [ $changed = 1 ] && info "Tambalan: GooglePackageInstaller dibuang, GApps pakai PackageInstaller Lunaris"
    return 0
}

# FPS per aplikasi (seperti RROS/Lunaris): Pengaturan > Tampilan > "Refresh rate per aplikasi".
# Framework (RefreshRatePolicy + PerAppRefreshRateStore) membaca Settings.System per_app_refresh_rate
# ("paket=rate,paket=rate"); app Settings menyediakan layar pemilihannya. Rate yang dipilih
# diabaikan untuk aplikasi kamera (rentang kamera Android 16 tidak diubah).
FW_PERAPP_PATCH="$SRC/device/xiaomi/ingres/patches/frameworks_base/0002-per-app-refresh-rate.patch"
SET_PERAPP_PATCH="$SRC/device/xiaomi/ingres/patches/settings/0001-per-app-refresh-rate.patch"
apply_tree_patch() {
    local dir="$1" patch="$2" marker="$3" name="$4"
    [ -f "$patch" ] && [ -f "$dir/$marker" ] || return 0
    git -C "$dir" apply --check -R "$patch" 2>/dev/null && return 0   # sudah terpasang
    if ! git -C "$dir" apply "$patch" 2>/dev/null; then
        reset_patch_files "$dir" "$patch"
        git -C "$dir" apply "$patch" 2>/dev/null || {
            err "Tambalan $name tidak cocok lagi (source AxionOS berubah), dilewati"
            return 0
        }
    fi
    info "Tambalan: $name"
}
# AOD memudar halus sebelum layar mati (gaya HyperOS), mis. saat batas waktu AOD habis.
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

fix_per_app_refresh_rate() {
    apply_tree_patch frameworks/base "$FW_PERAPP_PATCH" \
        services/core/java/com/android/server/wm/RefreshRatePolicy.java \
        "refresh rate per aplikasi (framework)"
    apply_tree_patch packages/apps/Settings "$SET_PERAPP_PATCH" \
        res/xml/display_settings.xml "refresh rate per aplikasi (Settings)"
}

unpatch_source() {
    unpatch_dv_cfg
    if [ -f "$PI_PATCH" ] && git -C frameworks/base apply --check -R "$PI_PATCH" 2>/dev/null; then
        git -C frameworks/base apply -R "$PI_PATCH" || true
    fi
    git -C vendor/gms checkout -q -- '*.mk' 2>/dev/null || true
    if [ -f "$FW_PERAPP_PATCH" ] && git -C frameworks/base apply --check -R "$FW_PERAPP_PATCH" 2>/dev/null; then
        git -C frameworks/base apply -R "$FW_PERAPP_PATCH" || true
    fi
    if [ -f "$SET_PERAPP_PATCH" ] && git -C packages/apps/Settings apply --check -R "$SET_PERAPP_PATCH" 2>/dev/null; then
        git -C packages/apps/Settings apply -R "$SET_PERAPP_PATCH" || true
    fi
    if [ -f "$L3_PATCH" ] && [ -d "$L3_DIR/.git" -o -f "$L3_DIR/.git" ]; then
        if git -C "$L3_DIR" apply --check -R "$L3_PATCH" 2>/dev/null; then
            git -C "$L3_DIR" apply -R "$L3_PATCH" || true
        else
            reset_patch_files "$L3_DIR" "$L3_PATCH"   # versi tambalan lama
        fi
    fi
    git -C hardware/qcom-caf/sm8450/display checkout -q -- composer/hwc_display.cpp 2>/dev/null || true
    git -C vendor/xiaomi/gamekey checkout -q -- third_party/rust 2>/dev/null || true
    unpatch_aod_fade
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
    fix_dolby_vision
    fix_gamekey
    fix_launcher3_bubble
    fix_package_installer
    fix_per_app_refresh_rate
    fix_aod_fade
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
        [ -e "$f" ] && [ "$(basename "$f")" != axion.xml ] && mv -f "$f" "$f.bak" && info "Menyingkirkan $(basename "$f")"
    done
    curl -fsSL -o .repo/local_manifests/axion.xml "$MANIFEST_URL" || { err "Gagal unduh local manifest"; exit 1; }

    # sisa percobaan lama: folder ingres/xiaomi yang bukan hasil repo ini bikin
    # "unsupported checkout state" dan Android.bp lama (vendor common salah versi)
    reset_project() {
        local rel="${1#"$SRC"/}"; rel="${rel%/.git}"; rel="${rel%/}"
        case "$rel" in ""|/*|*..*) return ;; esac
        info "Menghapus checkout lama: $rel"
        rm -rf "${SRC:?}/$rel" "${SRC:?}/.repo/projects/$rel.git"
    }

    unpatch_source
    local n slog="$HOME/sync-axion.log"
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
        || ! [ -f kernel/xiaomi/sm8450/arch/arm64/configs/vendor/ingres_GKI.config ]; then
        info "Mengulang sync repo ingres yang belum lengkap"
        repo sync -c -j1 --force-sync device/xiaomi/ingres vendor/xiaomi/ingres kernel/xiaomi/sm8450 || true
    fi
    restore_leftovers
    move_leftovers
    patch_source
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

# ----------------------------------------------------------------- build
# --------------------------------------------- tanda tangan kingD2N
# AxionOS ditandatangani kunci pribadi yang SAMA dengan LineageOS 24 (~/.ingres-keys), disimpan
# di luar source supaya tidak hilang saat sync ulang dan tidak pernah masuk GitHub.
# Kunci yang belum ada (mis. verifiedboot khusus AxionOS) dibuat sekali di folder yang sama.
# SIGN=0 = cara lama: kunci acak AxionOS (gk -s) di dalam source.
KEYS_DIR="${KEYS_DIR:-$HOME/.ingres-keys}"
AX_KEY_NAMES="releasekey platform shared media networkstack sdk_sandbox bluetooth nfc verity testkey cyngn-app testcert verifiedboot"
KEY_SUBJECT="/C=ID/ST=Indonesia/L=Indonesia/O=kingD2N/OU=kingD2N/CN=kingD2N"
use_ingres_keys() {
    local k made=0 top="$PWD" priv="$PWD/vendor/lineage-priv/keys"
    mkdir -p "$KEYS_DIR" && chmod 700 "$KEYS_DIR"
    for k in $AX_KEY_NAMES; do
        [ -s "$KEYS_DIR/$k.pk8" ] && [ -s "$KEYS_DIR/$k.x509.pem" ] && continue
        rm -f "$KEYS_DIR/$k.pk8" "$KEYS_DIR/$k.x509.pem"
        # make_key menolak path bertitik (".ingres-keys"): jalankan dari dalam folder kunci
        (cd "$KEYS_DIR" && echo | "$top/development/tools/make_key" "$k" "$KEY_SUBJECT") >/dev/null 2>&1
        [ -s "$KEYS_DIR/$k.pk8" ] && [ -s "$KEYS_DIR/$k.x509.pem" ] \
            || { err "Gagal membuat kunci $k di $KEYS_DIR"; exit 1; }
        made=$((made+1))
    done
    chmod 600 "$KEYS_DIR"/* 2>/dev/null
    rm -rf "$priv" && mkdir -p "$priv"
    for k in $AX_KEY_NAMES; do
        cp -f "$KEYS_DIR/$k.pk8" "$KEYS_DIR/$k.x509.pem" "$priv/"
    done
    {
        echo 'PRODUCT_DEFAULT_DEV_CERTIFICATE := vendor/lineage-priv/keys/releasekey'
        echo 'PRODUCT_MAINLINE_SEPOLICY_DEV_CERTIFICATES := $(dir $(PRODUCT_DEFAULT_DEV_CERTIFICATE))'
        echo 'PRODUCT_MAINLINE_BLUETOOTH_SEPOLICY_DEV_CERTIFICATES := $(dir $(PRODUCT_DEFAULT_DEV_CERTIFICATE))'
    } > "$priv/keys.mk"
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
    if [ "$made" -gt 0 ]; then
        info "Tanda tangan kingD2N: $made kunci baru dibuat di $KEYS_DIR (backup ulang folder ini!)"
    else
        info "Tanda tangan kingD2N: pakai kunci LineageOS dari $KEYS_DIR"
    fi
}

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
    fix_kernel_headers
    info "Varian build: $VARIANT"
    set +u   # envsetup.sh / lunch memakai variabel yang belum diisi
    local start rc
    start=$(date +%s)
    info "ROM: $ROM_NAME"
    local gms
    case "${GAPPS:-gms}" in
        0|va|vanilla) gms=va;   info "Build vanilla (tanpa GApps)" ;;
        pico)         gms=pico; info "Build dengan GApps pico (minimal)" ;;
        core)         gms=core; info "Build dengan GApps core" ;;
        *)            gms=gms;  info "Build dengan GApps lengkap" ;;
    esac
    if [ "${DECRYPT:-1}" = 0 ]; then export TARGET_DECRYPTED_DATA=false; info "/data terenkripsi"; else export TARGET_DECRYPTED_DATA=true; info "/data tanpa enkripsi (decrypt)"; fi
    # shellcheck disable=SC1091
    source build/envsetup.sh >/dev/null
    # kunci tanda tangan sendiri (sekali saja; simpan, jangan dibuat ulang tiap build)
    # gk membaca ANDROID_KEY_PATH; kalau kosong, kunci ditulis ke "/nfc.pk8" dst (Permission denied).
    # Hanya diisi kalau belum ada (variabel server tidak ditimpa).
    export ANDROID_KEY_PATH="${ANDROID_KEY_PATH:-$PWD/vendor/lineage-priv/keys}"
    if [ "${SIGN:-1}" != 0 ]; then
        use_ingres_keys
    elif [ ! -f "$ANDROID_KEY_PATH/releasekey.pk8" ]; then
        info "Membuat kunci tanda tangan (gk -s) di $ANDROID_KEY_PATH"
        mkdir -p "$ANDROID_KEY_PATH"
        gk -s >/dev/null || { err "gk -s gagal membuat kunci"; exit 1; }
        [ -f "$ANDROID_KEY_PATH/releasekey.pk8" ] || { err "kunci tanda tangan tidak terbentuk di $ANDROID_KEY_PATH"; exit 1; }
    fi
    # axion = lunch versi AxionOS (mengatur WITH_GMS & varian GApps)
    axion ingres "$VARIANT" "$gms"
    [ "$TARGET_PRODUCT" = lineage_ingres ] || { err "axion ingres $VARIANT $gms gagal (cek local manifest / sync)"; exit 1; }
    # langsung m bacon (perintah 'ax' selalu installclean dulu = build ulang lebih lama)
    m bacon -j"$jobs" 2>&1 | tee "$LOG"
    rc=${PIPESTATUS[0]}
    echo "Durasi: $(( ($(date +%s) - start) / 60 )) menit"

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
        echo "Setelah source ditambal, lanjutkan dengan: bash $SCRIPT"
        exit 1
    fi

    local p="out/target/product/ingres" zip
    zip=$(ls -t "$p"/axion-*.zip 2>/dev/null | head -n 1)
    [ -n "$zip" ] || { err "Build selesai tapi zip tidak ditemukan"; exit 1; }
    mkdir -p "$HASIL_DIR"
    cp "$zip" $p/boot.img $p/dtbo.img $p/vendor_boot.img $p/recovery.img "$HASIL_DIR"/ 2>/dev/null
    (cd "$HASIL_DIR" && sha256sum "$(basename "$zip")" > "$(basename "$zip").sha256")
    ok "BUILD BERHASIL"
    ls -lh "$HASIL_DIR"
    if [ "${GOFILE:-1}" != 0 ]; then
        do_upload || echo "Upload GoFile gagal. Ulangi dengan: bash $SCRIPT upload"
    else
        echo "Ambil file di folder $HASIL_DIR lewat SFTP Termius."
    fi
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
