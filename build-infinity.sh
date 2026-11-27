#!/usr/bin/env bash
#
# Build Project Infinity X terbaru (v4.x, Android 17, branch 17, berbasis LineageOS 24)
# untuk POCO F4 GT (ingres) - satu perintah.
#
#   bash build-infinity.sh            # sync + build (otomatis jalan di byobu)
#   bash build-infinity.sh sync       # hanya sync source
#   bash build-infinity.sh build      # hanya build (lanjut dari build sebelumnya)
#   bash build-infinity.sh status     # lihat progres build yang sedang jalan
#   bash build-infinity.sh upload     # upload ulang isi ~/hasil-infinity ke GoFile
#   bash build-infinity.sh clean      # hapus hasil build lama (out/) lalu berhenti
#   bash build-infinity.sh bersih ~/axion   # hapus source ROM lain / folder lama
#   bash build-infinity.sh reset-ingres     # hapus repo ingres/xiaomi lama lalu sync ulang
#
# Pengaturan (opsional, isi sebelum perintah, contoh: VARIANT=userdebug bash build-infinity.sh):
#   SRC=~/infinity     folder source
#   JOBS=<angka>       jumlah job build (default: otomatis dari CPU & RAM)
#   VARIANT=user       user (rilis, default) / userdebug / eng
#   GAPPS=0            build vanilla tanpa GApps (default: dengan GApps)
#   DECRYPT=0          /data terenkripsi seperti biasa (default: decrypt)
#   DV_TMAX=800        batas terang Dolby Vision (nit) layar F4 GT (0 = setelan asli Sony)
#   AOD_FADE_MS=500    lama AOD memudar sebelum layar mati, ms (0 = tanpa, perilaku asli)
#   BOOTLOG=1          build pelacak bootloop: userdebug + logcat tersimpan di /data/misc/logd (ambil via TWRP)
#   SIGN=0             kunci bawaan ROM (default: tanda tangan kingD2N = kunci LineageOS, ~/.ingres-keys)
#   GOFILE=0           jangan upload hasil ke GoFile (default: upload otomatis)
#   GOFILE_TOKEN=xxx   token akun GoFile (opsional)

set -uo pipefail

ROM=infinity
ROM_NAME="Project Infinity X (17)"
ROM_MANIFEST="https://github.com/ProjectInfinity-X/manifest"; ROM_BRANCH="17"
# sesuai README Infinity X: tanpa grup mips/darwin/notdefault
# shellcheck disable=SC2054
REPO_ARGS=(--no-repo-verify -g default,-mips,-darwin,-notdefault)
SRC="${SRC:-$HOME/infinity}"
VARIANT="${VARIANT:-user}"
# BOOTLOG=1: build pelacak bootloop (userdebug + logcat disimpan ke /data/misc/logd)
[ "${BOOTLOG:-0}" = 1 ] && VARIANT=userdebug
SESSION="infinity"
LOG="$HOME/build-infinity.log"
MANIFEST_URL="https://raw.githubusercontent.com/kingD2N/android_device_xiaomi_ingres-old/infinity-17/local_manifests/infinity.xml"
HASIL_DIR="$HOME/hasil-infinity"
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
    for d in "$HOME/los24" "$HOME/hasil-los24" "$HOME/build.log" "$HOME/los24-sisa-lama" \
             "$HOME/lunaris" "$HOME/hasil-lunaris" "$HOME/build-lunaris.log" "$HOME/lunaris-sisa-lama" \
             "$HOME/axion" "$HOME/hasil-axion" "$HOME/build-axion.log" "$HOME/axion-sisa-lama" \
             "$HOME/ascp" "$HOME/hasil-ascp" "$HOME/build-ascp.log" "$HOME/ascp-sisa-lama" \
             "$HOME/uwu" "$HOME/hasil-uwu" "$HOME/build-uwu.log" "$HOME/uwu-sisa-lama" "$HOME/rbe-diag.txt" \
             "$HOME/aospa" "$HOME/build-aospa.log" \
             "$HOME/pixelos" "$HOME/hasil-pixelos" "$HOME/build-pixelos.log" "$HOME/pixelos-sisa-lama" \
             "$HOME/evox" "$HOME/hasil-evox" "$HOME/build-evox.log" "$HOME/evox-sisa-lama" \
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
    echo "Simpan dulu zip ROM lama (mis. ~/hasil-lunaris, ~/hasil-aospa) lewat SFTP kalau masih perlu."
    read -r -p "Ketik YA lalu Enter untuk menghapus: " jawab
    [ "$jawab" = "YA" ] || { info "Batal, tidak ada yang dihapus."; exit 0; }
    for s in los24 aospa lunaris axion ascp uwu infinity evox pixelos; do
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
    envs="SRC='$SRC' VARIANT='$VARIANT' DECRYPT='${DECRYPT:-1}' BOOTLOG='${BOOTLOG:-0}' GPU_DRIVER='${GPU_DRIVER:-}' GPU_ZIP='${GPU_ZIP:-}' SIGN='${SIGN:-1}' KEYS_DIR='${KEYS_DIR:-}' AOD_FADE_MS='${AOD_FADE_MS:-500}' DV_TMAX='${DV_TMAX:-800}' GOFILE='${GOFILE:-1}' GOFILE_TOKEN='${GOFILE_TOKEN:-}' JOBS='${JOBS:-}' RBE='${RBE:-}' GAPPS='${GAPPS:-1}'"
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
    local known d bak="$HOME/infinity-sisa-lama"
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
    local known d bak="$HOME/infinity-sisa-lama"
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

# Kalau build membuat image vendor lewat Soong (fsgen, <produk>_generated_vendor_image):
# fsgen mengumpulkan arsitektur per NAMA modul, jadi prebuilt vendor 64-bit yang
# namanya sama dengan modul AOSP 32+64-bit (libomp dari prebuilts/clang) ikut diminta
# varian arm 32-bit -> 'dependency "//vendor/xiaomi/ingres:libomp" ... missing variant'.
# Ganti nama modul prebuilt itu (nama file .so tetap lewat "stem").
# Daftar: libomp + nama yang dilaporkan fsgen di log build sebelumnya.
fix_fsgen_dupes() {
    local list="vendor/xiaomi/ingres:libomp" extra
    if [ -f "$LOG" ]; then
        extra=$(grep -oE 'dependency "//vendor/xiaomi/[^:"]+:[^"]+" of "[^"]*_generated_[a-z_]*image" missing variant' "$LOG" \
                | sed -E 's#^dependency "//([^"]+)".*#\1#' | sort -u)
        list="$list $extra"
    fi
    python3 -I - $list <<'PY'
import os, re, sys
done = set()
for item in sys.argv[1:]:
    d, _, name = item.partition(":")
    if not name or item in done or not os.path.isdir(d):
        continue
    done.add(item)
    bp = os.path.join(d, "Android.bp")
    if not os.path.isfile(bp):
        continue
    s = open(bp).read()
    new = name + "_ingres"
    q = '"%s"' % name
    if ('name: %s,' % q) not in s:
        continue
    # rujukan shared_libs / required + definisi modul di file yang sama
    s = s.replace(q + ",", '"%s",' % new)
    # stem supaya file terpasang tetap <name>.so
    s = s.replace('name: "%s",' % new, 'name: "%s",\n    stem: %s,' % (new, q), 1)
    open(bp, "w").write(s)
    for f in os.listdir(d):
        if f.endswith(".mk"):
            fp = os.path.join(d, f)
            t = open(fp).read()
            t2 = re.sub(r'(?m)(^|\s)%s(?=\s|\\|$)' % re.escape(name), lambda m: m.group(1) + new, t)
            if t2 != t:
                open(fp, "w").write(t2)
    print("[..] Tambalan fsgen: %s/%s -> %s (file tetap %s.so)" % (d, name, new, name))
PY
}

# FPS per aplikasi: Pengaturan > Tampilan > "Refresh rate per aplikasi".
# Framework (RefreshRatePolicy + PerAppRefreshRateStore) membaca Settings.System per_app_refresh_rate
# ("paket=rate,paket=rate"); app Settings menyediakan layar pemilihannya. Rate pilihan diabaikan
# untuk aplikasi kamera (rentang kamera Android 16 tidak diubah). ROM yang sudah punya fitur
# serupa sendiri tidak ditambal.
FW_PERAPP_PATCH="$SRC/device/xiaomi/ingres/patches/frameworks_base/0002-per-app-refresh-rate.patch"
SET_PERAPP_PATCH="$SRC/device/xiaomi/ingres/patches/settings/0001-per-app-refresh-rate.patch"
# Kembalikan berkas yang disentuh sebuah tambalan ke kondisi repo (tambalan lama tidak bisa di-reverse).
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
apply_tree_patch() {
    local dir="$1" patch="$2" marker="$3" name="$4"
    [ -f "$patch" ] && [ -f "$dir/$marker" ] || return 0
    git -C "$dir" apply --check -R "$patch" 2>/dev/null && return 0   # sudah terpasang
    if ! git -C "$dir" apply "$patch" 2>/dev/null; then
        reset_patch_files "$dir" "$patch"
        git -C "$dir" apply "$patch" 2>/dev/null || {
            err "Tambalan $name tidak cocok lagi (source ROM berubah), dilewati"
            return 0
        }
    fi
    info "Tambalan: $name"
}
fix_per_app_refresh_rate() {
    [ -f "$SET_PERAPP_PATCH" ] && [ -f packages/apps/Settings/res/xml/display_settings.xml ] || return 0
    if ! git -C packages/apps/Settings apply --check -R "$SET_PERAPP_PATCH" 2>/dev/null \
        && grep -rqsiE 'key="[a-z_]*(per_app_refresh|app_refresh_rate|screen_refresh_rate)[a-z_]*"' \
            packages/apps/Settings/res/xml 2>/dev/null; then
        info "FPS per aplikasi: ROM ini sudah punya sendiri, tambalan dilewati"
        return 0
    fi
    apply_tree_patch frameworks/base "$FW_PERAPP_PATCH" \
        services/core/java/com/android/server/wm/RefreshRatePolicy.java \
        "refresh rate per aplikasi (framework)"
    apply_tree_patch packages/apps/Settings "$SET_PERAPP_PATCH" \
        res/xml/display_settings.xml "refresh rate per aplikasi (Settings)"
}
unpatch_per_app_refresh_rate() {
    if [ -f "$FW_PERAPP_PATCH" ] && git -C frameworks/base apply --check -R "$FW_PERAPP_PATCH" 2>/dev/null; then
        git -C frameworks/base apply -R "$FW_PERAPP_PATCH" || true
    fi
    if [ -f "$SET_PERAPP_PATCH" ] && git -C packages/apps/Settings apply --check -R "$SET_PERAPP_PATCH" 2>/dev/null; then
        git -C packages/apps/Settings apply -R "$SET_PERAPP_PATCH" || true
    fi
}

# Launcher3 bawaan: geser ke atas dari aplikasi melewati batas (ada getar), lepas ->
# aplikasi dibuka sebagai gelembung (bubble). Pengaturan ada di Setelan Layar utama.
# Tambalan dijaga: kalau Launcher3 Infinity X tidak cocok, dilewati dengan pesan jelas.
L3_DIR=packages/apps/Launcher3
L3_PATCH="$SRC/device/xiaomi/ingres/patches/launcher3/0001-recents-freeform-gesture.patch"
L3_XML=res/xml/launcher_preferences.xml
L3_KT=src/com/android/launcher3/LauncherPrefs.kt
# Saklar + batas geser di Setelan Layar utama. Disisipkan lewat skrip (bukan tambalan baris)
# karena letak baris di launcher_preferences.xml / LauncherPrefs.kt beda-beda tiap ROM.
l3_bubble_prefs() {
    python3 - "$L3_DIR/$L3_XML" "$L3_DIR/$L3_KT" <<'PYEOF'
import re, sys
xml, kt = sys.argv[1], sys.argv[2]
block = """    <SwitchPreferenceCompat
        android:defaultValue="false"
        android:key="pref_recents_freeform_gesture"
        android:persistent="true"
        android:title="@string/pref_recents_freeform_gesture_title"
        android:summary="@string/pref_recents_freeform_gesture_summary" />

    <DropDownPreference
        android:defaultValue="60"
        android:dependency="pref_recents_freeform_gesture"
        android:entries="@array/pref_recents_freeform_threshold_entries"
        android:entryValues="@array/pref_recents_freeform_threshold_values"
        android:key="pref_recents_freeform_threshold"
        android:persistent="true"
        android:title="@string/pref_recents_freeform_threshold_title"
        android:summary="%s" />

"""
s = open(xml).read()
if "pref_recents_freeform_gesture" not in s:
    ms = list(re.finditer(r"</(?:androidx\.preference\.)?PreferenceScreen>", s))
    if not ms:
        sys.exit("penutup PreferenceScreen tidak ketemu")
    i = ms[-1].start()
    open(xml, "w").write(s[:i] + block + s[i:])
k = open(kt).read()
if "RECENTS_FREEFORM_GESTURE" not in k:
    if "backedUpItem(" not in k:
        sys.exit("backedUpItem tidak ada di LauncherPrefs.kt")
    m = re.search(r"companion object\s*\{\n", k)
    if not m:
        sys.exit("companion object tidak ketemu di LauncherPrefs.kt")
    add = ("        @JvmField\n"
           "        val RECENTS_FREEFORM_GESTURE = backedUpItem(\"pref_recents_freeform_gesture\", false)\n"
           "        @JvmField\n"
           "        val RECENTS_FREEFORM_THRESHOLD = backedUpItem(\"pref_recents_freeform_threshold\", \"60\")\n")
    open(kt, "w").write(k[:m.end()] + add + k[m.end():])
PYEOF
}
fix_launcher3_bubble() {
    [ -f "$L3_PATCH" ] || return 0
    if [ ! -f "$L3_DIR/quickstep/src/com/android/quickstep/AbsSwipeUpHandler.java" ]; then
        err "Launcher3 bawaan tidak punya quickstep/AbsSwipeUpHandler, gelembung geser-atas dilewati"
        return 0
    fi
    if ! git -C "$L3_DIR" apply --check -R "$L3_PATCH" 2>/dev/null \
        && grep -rqsE 'class (RecentsFreeformGesture|BubbleSwipe)' "$L3_DIR/quickstep/src" 2>/dev/null; then
        info "Gelembung geser-atas: Launcher3 ini sudah punya sendiri, tambalan dilewati"
        return 0
    fi
    apply_tree_patch "$L3_DIR" "$L3_PATCH" \
        quickstep/src/com/android/quickstep/AbsSwipeUpHandler.java \
        "Launcher3 geser ke atas -> gelembung aplikasi"
    [ -f "$L3_DIR/quickstep/src/com/android/quickstep/util/RecentsFreeformGesture.java" ] || return 0
    if l3_bubble_prefs; then
        info "Tambalan: saklar gelembung di Setelan Layar utama"
    else
        err "Saklar gelembung gagal dipasang (struktur Launcher3 beda), seluruh tambalan gelembung dibatalkan"
        unpatch_launcher3_bubble
    fi
}
unpatch_launcher3_bubble() {
    if [ -f "$L3_PATCH" ] && git -C "$L3_DIR" apply --check -R "$L3_PATCH" 2>/dev/null; then
        git -C "$L3_DIR" apply -R "$L3_PATCH" || true
    fi
    git -C "$L3_DIR" checkout -q -- "$L3_XML" "$L3_KT" 2>/dev/null || true
}

# EKSPERIMEN: driver GPU Adreno V837.0.9 ditanam langsung ke image vendor.
# Zip diambil dari ~/gpu (atau GPU_ZIP=/path/zip); varian B (grafis saja) diutamakan.
# Tidak ada zip / GPU_DRIVER=off -> build normal. Blob stok di repo vendor ditimpa
# di tempat (dikembalikan lewat git checkout sebelum sync / build berikutnya).
GPU_DIR=vendor/ingres/gpu
GPU_LIST="$SRC/.gpu_replaced"
unpatch_gpu_driver() {
    local p repo
    if [ -f "$GPU_LIST" ]; then
        while IFS= read -r p; do
            [ -n "$p" ] || continue
            repo=$(echo "$p" | cut -d/ -f1-3)
            git -C "$repo" checkout -q -- "${p#"$repo"/}" 2>/dev/null || true
        done < "$GPU_LIST"
        rm -f "$GPU_LIST"
    fi
    rm -rf "${SRC:?}/$GPU_DIR"
}
# Blob V837 butuh DT_NEEDED yang tidak tercatat di shared_libs Android.bp vendor
# (liblog, libnativewindow, libadreno_utils, ...) -> Soong 'check_elf_file' gagal.
# Cek itu dimatikan hanya untuk modul yang blobnya kita timpa. $1=repo vendor, sisanya
# path blob relatif ke repo. Android.bp dikembalikan lewat git checkout (unpatch_gpu_driver).
gpu_relax_elf_check() {
    python3 - "$@" <<'PYEOF'
import re, sys
repo, files = sys.argv[1], sys.argv[2:]
p = repo + "/Android.bp"
try:
    s = open(p).read()
except OSError:
    sys.exit(0)
blocks, depth, start = [], 0, None
for i, c in enumerate(s):
    if c == "{":
        if depth == 0:
            start = i
        depth += 1
    elif c == "}" and depth:
        depth -= 1
        if depth == 0:
            blocks.append((start, i))
edits = 0
for bs, be in reversed(blocks):
    t = s[bs:be]
    if "check_elf_files" in t or not any(f in t for f in files):
        continue
    t2, n = re.subn(r'(\n[ \t]*name:[ \t]*"[^"]*",)', r'\1\n    check_elf_files: false,', t, count=1)
    if n:
        s = s[:bs] + t2 + s[be:]
        edits += 1
if edits:
    open(p, "w").write(s)
print(edits)
PYEOF
}
fix_gpu_driver() {
    unpatch_gpu_driver
    [ "${GPU_DRIVER:-}" = off ] && { info "Driver GPU V837: dimatikan (GPU_DRIVER=off)"; return 0; }
    local zip="${GPU_ZIP:-}" f
    if [ -z "$zip" ]; then
        for f in "$HOME"/gpu/*B_grafis_saja*.zip "$HOME"/gpu/*A_lengkap*.zip; do
            [ -f "$f" ] && { zip="$f"; break; }
        done
    fi
    [ -n "$zip" ] && [ -f "$zip" ] || return 0
    local tmp; tmp=$(mktemp -d) || return 0
    if ! unzip -q -o "$zip" 'lib/*' 'lib64/*' qgl_config.txt -d "$tmp"; then
        err "Zip driver GPU rusak/tidak terbaca: $zip (dilewati)"; rm -rf "$tmp"; return 0
    fi
    # gpu/kbc (bytecode compute, hanya ada di varian A) - opsional
    unzip -q -o "$zip" 'gpu/*' -d "$tmp" >/dev/null 2>&1 || true
    local rel dst n=0 miss="" newgpu=""
    while IFS= read -r f; do
        rel="${f#"$tmp"/}"
        dst=$(find vendor/xiaomi -type f -path "*/proprietary/vendor/$rel" 2>/dev/null | head -n 1)
        if [ -n "$dst" ]; then
            # simpan versi stok backend OpenCL sebelum ditimpa (untuk stack OpenCL khusus kamera)
            case "$rel" in
                lib64/libCB.so|lib64/libgsl.so|lib64/libadreno_utils.so)
                    mkdir -p "$tmp/.stock" && cp -f "$dst" "$tmp/.stock/${rel#lib64/}" ;;
            esac
            cp -f "$f" "$dst" && { echo "$dst" >> "$GPU_LIST"; n=$((n+1)); }
        else
            case "$rel" in
                */hw/*) miss="$miss $rel" ;;      # HAL 32-bit (vulkan) tidak ada di ROM 64-bit, dilewati
                *)      newgpu="$newgpu $rel" ;;  # belum ada di repo vendor (mis. libOpenCL_adreno) -> ditambah lewat gpu.mk
            esac
        fi
    done < <(find "$tmp/lib64" "$tmp/lib" "$tmp/gpu" -type f 2>/dev/null | sort)
    if [ "$n" -eq 0 ]; then
        err "Driver GPU V837: tidak ada blob Adreno yang cocok di vendor/xiaomi, dilewati"
        rm -rf "$tmp"; return 0
    fi
    local repo m rels
    for repo in $(sed 's#^\(vendor/xiaomi/[^/]*\)/.*#\1#' "$GPU_LIST" | sort -u); do
        rels=$(grep "^$repo/" "$GPU_LIST" | sed "s#^$repo/##")
        # shellcheck disable=SC2086
        m=$(gpu_relax_elf_check "$repo" $rels) || m=0
        if [ "${m:-0}" -gt 0 ] 2>/dev/null; then
            echo "$repo/Android.bp" >> "$GPU_LIST"
            info "Driver GPU V837: cek ELF Soong dimatikan untuk $m modul di $repo"
        fi
    done
    mkdir -p "$GPU_DIR"
    cp -f "$tmp/qgl_config.txt" "$GPU_DIR/qgl_config.txt"
    cat > "$GPU_DIR/init.ingres_gpu.rc" <<'RC'
# qgl_config.txt untuk driver Adreno V837 (pengganti langkah TWRP: salin ke /data/vendor/gpu)
on post-fs-data
    mkdir /data/vendor/gpu 0771 system system
    copy /vendor/etc/qgl_config.txt /data/vendor/gpu/qgl_config.txt
    chmod 0644 /data/vendor/gpu/qgl_config.txt
    restorecon /data/vendor/gpu/qgl_config.txt
RC
    cat > "$GPU_DIR/gpu.mk" <<'MK'
PRODUCT_COPY_FILES += \
    vendor/ingres/gpu/qgl_config.txt:$(TARGET_COPY_OUT_VENDOR)/etc/qgl_config.txt \
    vendor/ingres/gpu/init.ingres_gpu.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.ingres_gpu.rc
MK
    # File ELF (.so) tidak boleh lewat PRODUCT_COPY_FILES (Soong: "found ELF prebuilt in PRODUCT_COPY_FILES"),
    # jadi dideklarasikan sebagai cc_prebuilt_library_shared dan dimasukkan lewat PRODUCT_PACKAGES.
    # File non-ELF (gpu/kbc) tetap lewat PRODUCT_COPY_FILES.
    local b name has32 has64 pkgs=""
    for rel in $newgpu; do
        mkdir -p "$GPU_DIR/$(dirname "$rel")"
        cp -f "$tmp/$rel" "$GPU_DIR/$rel"
        case "$rel" in
            lib/*.so|lib64/*.so) ;;
            *) printf 'PRODUCT_COPY_FILES += vendor/ingres/gpu/%s:$(TARGET_COPY_OUT_VENDOR)/%s\n' "$rel" "$rel" >> "$GPU_DIR/gpu.mk" ;;
        esac
    done
    : > "$GPU_DIR/Android.bp"
    for b in $(for rel in $newgpu; do case "$rel" in lib/*.so|lib64/*.so) basename "$rel" ;; esac; done | sort -u); do
        name="${b%.so}"; has32=""; has64=""
        case " $newgpu " in *" lib/$b "*)   has32=1 ;; esac
        case " $newgpu " in *" lib64/$b "*) has64=1 ;; esac
        {
            printf 'cc_prebuilt_library_shared {\n    name: "%s",\n    vendor: true,\n    check_elf_files: false,\n    strip: { none: true },\n' "$name"
            if [ -n "$has32" ] && [ -n "$has64" ]; then
                printf '    compile_multilib: "both",\n    arch: {\n        arm: { srcs: ["lib/%s"] },\n        arm64: { srcs: ["lib64/%s"] },\n    },\n' "$b" "$b"
            elif [ -n "$has64" ]; then
                printf '    compile_multilib: "64",\n    srcs: ["lib64/%s"],\n' "$b"
            else
                printf '    compile_multilib: "32",\n    srcs: ["lib/%s"],\n' "$b"
            fi
            printf '}\n\n'
        } >> "$GPU_DIR/Android.bp"
        pkgs="$pkgs $name"
    done
    # Stack OpenCL khusus kamera: kalau zip tidak membawa libOpenCL.so sendiri (varian B), libOpenCL stok
    # tidak cocok dengan libCB/libgsl V837 -> MIUI Camera "No OpenCL devices found". Hanya proses camera
    # provider yang diarahkan ke salinan stok di /vendor/lib64/camera_cl; GPU sistem tetap V837.
    local camrc
    if [ "${GPU_CAMCL:-}" != off ] && [ ! -f "$tmp/lib64/libOpenCL.so" ] && [ -d "$tmp/.stock" ]; then
        camrc=$(find vendor/xiaomi -type f -path "*/proprietary/vendor/etc/init/vendor.qti.camera.provider@2.7-service_64.rc" 2>/dev/null | head -n 1)
        if [ -n "$camrc" ] && grep -q '^service ' "$camrc"; then
            mkdir -p "$GPU_DIR/camera_cl"
            for b in "$tmp"/.stock/*.so; do
                b=$(basename "$b"); name="${b%.so}"
                cp -f "$tmp/.stock/$b" "$GPU_DIR/camera_cl/$b"
                printf 'cc_prebuilt_library_shared {\n    name: "%s_camcl",\n    stem: "%s",\n    vendor: true,\n    relative_install_path: "camera_cl",\n    check_elf_files: false,\n    strip: { none: true },\n    compile_multilib: "64",\n    srcs: ["camera_cl/%s"],\n}\n\n' "$name" "$name" "$b" >> "$GPU_DIR/Android.bp"
                pkgs="$pkgs ${name}_camcl"
            done
            awk '{print} /^service /{print "    override"; print "    setenv LD_LIBRARY_PATH /vendor/lib64/camera_cl"}' "$camrc" > "$GPU_DIR/zz.ingres_camera_cl.rc"
            printf 'PRODUCT_COPY_FILES += vendor/ingres/gpu/zz.ingres_camera_cl.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/zz.ingres_camera_cl.rc\n' >> "$GPU_DIR/gpu.mk"
            info "  OpenCL stok khusus kamera:$(cd "$tmp/.stock" && printf ' %s' *.so) -> /vendor/lib64/camera_cl"
        else
            info "  rc camera provider tidak ditemukan, OpenCL khusus kamera dilewati"
        fi
    fi
    [ -n "$pkgs" ] && printf 'PRODUCT_PACKAGES +=%s\n' "$pkgs" >> "$GPU_DIR/gpu.mk"
    [ -s "$GPU_DIR/Android.bp" ] || rm -f "$GPU_DIR/Android.bp"
    rm -rf "$tmp"
    info "Driver GPU V837: $n blob ditimpa dari $(basename "$zip")"
    [ -n "$newgpu" ] && info "  ditambahkan baru ke vendor:$newgpu"
    [ -n "$miss" ] && info "  tidak ada di vendor repo (dilewati):$miss"
    return 0
}

unpatch_source() {
    unpatch_dv_cfg
    unpatch_aod_fade
    unpatch_signing
    unpatch_per_app_refresh_rate
    unpatch_launcher3_bubble
    unpatch_gpu_driver
    git -C hardware/qcom-caf/sm8450/display checkout -q -- composer/hwc_display.cpp 2>/dev/null || true
    git -C vendor/xiaomi/gamekey checkout -q -- third_party/rust daemon/src 2>/dev/null || true
    local v
    for v in vendor/xiaomi/*/; do
        git -C "$v" checkout -q -- Android.bp ':(glob)*.mk' 2>/dev/null || true
    done
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
    fix_per_app_refresh_rate
    fix_launcher3_bubble
    fix_gpu_driver
    fix_fsgen_dupes
    fix_dolby_vision
    fix_gamekey
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
        repo init "${REPO_ARGS[@]}" -u "$ROM_MANIFEST" -b "$ROM_BRANCH" \
            --git-lfs --no-clone-bundle --depth=1 || { err "repo init gagal"; exit 1; }
    elif [ "${cur_url%.git}" != "$ROM_MANIFEST" ] || { [ -n "$cur_branch" ] && [ "$cur_branch" != "$ROM_BRANCH" ]; }; then
        info "Pindah manifest ke $ROM_NAME (source yang sama dipakai ulang)"
        repo init "${REPO_ARGS[@]}" -u "$ROM_MANIFEST" -b "$ROM_BRANCH" \
            --git-lfs --no-clone-bundle --depth=1 || { err "repo init gagal"; exit 1; }
    fi
    mkdir -p .repo/local_manifests
    # local manifest lama (percobaan sebelumnya) bisa bentrok, singkirkan
    for f in .repo/local_manifests/*.xml; do
        [ -e "$f" ] && [ "$(basename "$f")" != infinity.xml ] && mv -f "$f" "$f.bak" && info "Menyingkirkan $(basename "$f")"
    done
    curl -fsSL -o .repo/local_manifests/infinity.xml "$MANIFEST_URL?$(date +%s)" || { err "Gagal unduh local manifest"; exit 1; }

    # sisa percobaan lama: folder ingres/xiaomi yang bukan hasil repo ini bikin
    # "unsupported checkout state" dan Android.bp lama (vendor common salah versi)
    reset_project() {
        local rel="${1#"$SRC"/}"; rel="${rel%/.git}"; rel="${rel%/}"
        case "$rel" in ""|/*|*..*) return ;; esac
        info "Menghapus checkout lama: $rel"
        rm -rf "${SRC:?}/$rel" "${SRC:?}/.repo/projects/$rel.git"
    }

    unpatch_source
    local n slog="$HOME/sync-infinity.log"
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
    ok "Source siap di $SRC"
}

# Header kernel hasil generate (generated_kernel_includes) hanya dibuat ulang kalau
# Makefile/include kernel berubah. Kalau header UAPI vendor (audio/display) tidak
# lengkap, hapus supaya dibuat ulang dari kernel yang sekarang.
# Hasil compile yang kosong (0 byte) tidak pernah valid: tertinggal dari build yang
# terputus, disk penuh, atau unduhan RBE (remote_local_fallback) yang gagal. Ninja
# menganggapnya sudah jadi, lalu modul berikutnya gagal, mis. "found invalid metadata
# files for crate serde ... memory map must have a non-zero length". Hapus supaya
# dibuat ulang.
clean_broken_outputs() {
    local d=out/soong/.intermediates n
    [ -d "$d" ] || return 0
    n=$(find "$d" -type f -size 0 \( -name '*.rlib' -o -name '*.rmeta' -o -name '*.jar' \
          -o -name '*.so' -o -name '*.a' -o -name '*.o' -o -name '*.dex' -o -name '*.apk' -o -name 'flags.txt' \) \
          -print -delete 2>/dev/null | wc -l)
    [ "$n" -gt 0 ] && info "Menghapus $n hasil compile kosong (rusak) di out/, akan dibuat ulang"
    # jar terpotong ("Invalid or corrupt jarfile .../metalava.jar"): cek direktori ZIP-nya
    n=$(find out/host/linux-x86/framework "$d" -type f -name '*.jar' -size +0 2>/dev/null | python3 -I -c '
import sys, zipfile, os
bad = 0
for line in sys.stdin:
    f = line.rstrip("\n")
    try:
        with zipfile.ZipFile(f) as z:
            z.infolist()
    except Exception:
        try:
            os.remove(f); bad += 1
        except OSError:
            pass
print(bad)')
    [ "${n:-0}" -gt 0 ] && info "Menghapus $n file jar rusak di out/, akan dibuat ulang"
    # .so/.o/.a terpotong ("ld.lld: error: .../libui.so: unknown file type"): cek header-nya
    n=$(find "$d" out/host/linux-x86/lib64 -type f \( -name '*.so' -o -name '*.o' -o -name '*.a' \) \
          -size +0 2>/dev/null | python3 -I -c '
import sys, os
bad = 0
for line in sys.stdin:
    f = line.rstrip("\n")
    try:
        with open(f, "rb") as h:
            head = h.read(8)
        if f.endswith(".a"):
            ok = head in (b"!<arch>\n", b"!<thin>\n")
        else:
            # ELF, bitcode LLVM (objek LTO), atau skrip linker teks (INPUT(...), /* ... */)
            ok = head[:4] in (b"\x7fELF", b"BC\xc0\xde", b"\xde\xc0\x17\x0b") or \
                 head.lstrip()[:2] == b"/*" or head.lstrip()[:5] in (b"INPUT", b"GROUP", b"OUTPU")
        if not ok:
            os.remove(f); bad += 1
    except OSError:
        pass
print(bad)')
    [ "${n:-0}" -gt 0 ] && info "Menghapus $n file .so/.o/.a rusak di out/, akan dibuat ulang"
    # build sebelumnya gagal karena hasil compile rusak (header dari flags.txt hilang,
    # rlib/jar terpotong): buang hasil compile modul yang gagal supaya dibuat ulang
    if [ -f "$LOG" ] && grep -q -e "file not found" -e "found invalid metadata files" \
            -e "Invalid or corrupt jarfile" -e "non-zero length" -e "unknown file type" "$LOG"; then
        local m dir cnt=0
        while read -r m; do
            dir="$d/${m#//}"; dir="${dir/://}"
            [ -d "$dir" ] || continue
            rm -rf "$dir"; cnt=$((cnt + 1))
        done < <(grep -o '^FAILED: //[^ ]*' "$LOG" | cut -d' ' -f2 | sort -u)
        [ "$cnt" -gt 0 ] && info "Menghapus hasil compile $cnt modul yang gagal di build lalu (akan dibuat ulang)"
    fi
    # build sebelumnya gagal di KSP (kotlin-ksp-client-lib: "unresolved reference 'impl'"):
    # jar KSP yang terbaca tidak lengkap -> sync ulang external/ksp + kotlinc dan
    # buang hasil compile modul itu
    if [ -f "$LOG" ] && grep -q "kotlin-ksp-client-lib\|devtools.ksp.impl" "$LOG"; then
        info "Build lalu gagal di KSP: sync ulang external/ksp & external/kotlinc"
        repo sync -c -j4 --force-sync --no-tags --no-clone-bundle external/ksp external/kotlinc >/dev/null 2>&1 \
            || err "sync external/ksp gagal (lanjut build)"
        rm -rf "$d/build/soong/cmd/kotlinc_incremental" "$d/external/ksp"
    fi
    return 0
}

fix_kernel_headers() {
    # Infinity X: modul generator kernel ada di vendor/infinity (LineageOS: vendor/lineage)
    local g=out/soong/.intermediates/vendor/infinity/build/soong/generated_kernel_includes
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
    [ -f "$SIGN_DEVMK" ] && sed -i -e "/$SIGN_MARK\$/d" -e '/# ingres-bootlog$/d' "$SIGN_DEVMK"
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
    # out/ dari build yang belum pernah selesai masih butuh banyak ruang
    if ls out/target/product/ingres/Project_Infinity-X-*.zip >/dev/null 2>&1; then check_disk 30
    elif [ -d out/target/product/ingres ]; then check_disk 100
    else check_disk 160; fi

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
    clean_broken_outputs
    info "Varian build: $VARIANT"
    if [ "${DECRYPT:-1}" = 0 ]; then export TARGET_DECRYPTED_DATA=false; info "/data terenkripsi"; else export TARGET_DECRYPTED_DATA=true; info "/data tanpa enkripsi (decrypt)"; fi
    setup_signing
    if [ "${BOOTLOG:-0}" = 1 ] && [ -f "$SIGN_DEVMK" ]; then
        # logcatd (hanya ada di userdebug) menulis log sejak boot ke /data/misc/logd, tetap ada
        # setelah bootloop dan bisa diambil dari TWRP. Dibuang lagi oleh unpatch_signing.
        sed -i -e '$a\' "$SIGN_DEVMK"
        cat >> "$SIGN_DEVMK" <<'BLEOF'
PRODUCT_SYSTEM_PROPERTIES += persist.logd.logpersistd=logcatd # ingres-bootlog
PRODUCT_SYSTEM_PROPERTIES += persist.logd.logpersistd.enable=true # ingres-bootlog
PRODUCT_SYSTEM_PROPERTIES += logd.logpersistd.enable=true # ingres-bootlog
PRODUCT_SYSTEM_PROPERTIES += persist.logd.logpersistd.size=64 # ingres-bootlog
PRODUCT_SYSTEM_PROPERTIES += persist.logd.logpersistd.buffer=all # ingres-bootlog
BLEOF
        info "BOOTLOG=1: build userdebug, logcat sejak boot disimpan di /data/misc/logd"
    fi
    set +u   # envsetup.sh / lunch memakai variabel yang belum diisi
    local start rc
    start=$(date +%s)
    info "ROM: $ROM_NAME"
    # shellcheck disable=SC1091
    source build/envsetup.sh >/dev/null
    # Infinity X 4.2: produk infinity_ingres. lunch di build/make memakai format lama
    # <produk>-<varian> (rilis diambil otomatis dari BUILD_ID) dan hanya mengisi
    # INFINITY_BUILD (yang menyalakan config board Infinity) untuk produk infinity_*
    if [ "${GAPPS:-1}" = 0 ]; then export WITH_GAPPS=false; info "Build vanilla (tanpa GApps)"; else export WITH_GAPPS=true; info "Build dengan GApps"; fi
    lunch "infinity_ingres-$VARIANT" || { err "lunch infinity_ingres-$VARIANT gagal (cek local manifest / sync)"; exit 1; }
    # lunch yang gagal tidak selalu mengembalikan error; build lalu jatuh ke aosp_arm64
    # tanpa config Infinity (protobuf_vendorcompat bentrok, dll) -> hentikan di sini
    if [ "${TARGET_PRODUCT:-}" != infinity_ingres ] || [ -z "${INFINITY_BUILD:-}" ]; then
        err "lunch tidak memilih infinity_ingres (TARGET_PRODUCT=${TARGET_PRODUCT:-kosong}, INFINITY_BUILD=${INFINITY_BUILD:-kosong})"
        exit 1
    fi
    info "Produk: $TARGET_PRODUCT, rilis: ${TARGET_RELEASE:-?}, varian: $TARGET_BUILD_VARIANT"
    # RBE diatur SETELAH envsetup/lunch (vendorsetup.sh atau profil server bisa menyalakannya lagi)
    local rbe_state
    # Environment build bawaan server (RBE_*, CUSTOM_NINJA_BIN, BASH_ENV, CC_WRAPPER, ...)
    # dipakai apa adanya: penjadwal build server menghentikan build yang menghapus
    # atau menimpa variabel itu ("Build Terminated (Setup Required)").
    rbe_state=server
    info "Environment build server dipakai apa adanya (aturan server)"
    rbe_state="$rbe_state ${CC_WRAPPER:-}"
    # juga kalau build lalu masih gagal karena rewrapper tanpa reproxy
    if [ "$(cat .rbe-ingres 2>/dev/null)" != "$rbe_state" ] || \
       { [ "${rbe_state%% *}" = off ] && [ -f "$LOG" ] && grep -q "server_address cannot be empty" "$LOG"; }; then
        # semua file analisis (ninja Soong + Kati + gabungan, catatan env Soong, variabel
        # produk) dibuang supaya tidak ada perintah lama ber-rewrapper yang tersisa;
        # hasil compile di out/ tetap dipakai
        rm -f out/soong/build.*.ninja* out/soong/soong.environment.used.* out/soong/soong.*.variables \
              out/build-*.ninja* out/combined-*.ninja* out/ninja-*.sh 2>/dev/null
        info "Status RBE berganti (${rbe_state%% *}): analisis build diulang (beberapa menit)"
    fi
    echo "$rbe_state" > .rbe-ingres
    m bacon -j"$jobs" 2>&1 | tee "$LOG"
    rc=${PIPESTATUS[0]}
    if [ "${rbe_state%% *}" = off ] && grep -q "/rewrapper " "$LOG"; then
        err "Perintah build masih memakai rewrapper (RBE) walau RBE mati. Screenshot info di bawah ini:"
        {
        echo "--- env ---"; env | grep -iE '^(USE_RBE|USE_REWRAPPER|NOSTART_RBE|CC_WRAPPER|CXX_WRAPPER|JAVAC_WRAPPER|RBE_[A-Z_]*|ANDROID_BUILD_ENVIRONMENT_CONFIG[A-Z_]*|BASH_ENV|ENV)=' | cut -c1-160
        echo "--- env di proses bash baru (seperti soong_ui.bash) ---"
        bash -c 'env' | grep -E '^(USE_RBE|RBE_DIR|CC_WRAPPER|BASH_ENV)=' | cut -c1-160
        echo "--- file profil yang memasang RBE ---"
        grep -lsE 'RBE_DIR|USE_RBE' /etc/environment /etc/profile /etc/profile.d/* /etc/bash.bashrc \
            "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bash_login" 2>/dev/null
        echo "--- rewrapper di ninja Soong: $(grep -c rewrapper out/soong/build.infinity_ingres.ninja 2>/dev/null || echo '?') baris"
        echo "--- env yang dipakai Soong ---"
        grep -hoE '"(USE_RBE|USE_REWRAPPER|CC_WRAPPER|RBE_WRAPPER)"[^,}]*' out/soong/soong.environment.used.infinity_ingres* 2>/dev/null | head -n 8 | cut -c1-160
        ls -la buildspec.mk* 2>/dev/null
        echo "--- makefile yang mengisi RBE ---"
        grep -rnsE '^[[:space:]]*(export[[:space:]]+)?(USE_RBE|USE_REWRAPPER|RBE_DIR|CC_WRAPPER)[[:space:]]*[:?+]?=' \
            --include='*.mk' buildspec.mk* device vendor product build/make/core 2>/dev/null \
            | grep -v -e 'core/rbe.mk' -e 'core/ccache.mk' | head -n 8 | cut -c1-160
        echo "--- CC_WRAPPER di ninja Soong ---"
        grep -m1 -o 'CcWrapper = .\{0,120\}' out/soong/build.infinity_ingres.ninja 2>/dev/null
        } 2>&1 | tee "$HOME/rbe-diag.txt"
        echo "Info ini juga tersimpan di ~/rbe-diag.txt (kirim: cat ~/rbe-diag.txt)"
    fi
    echo "Durasi: $(( ($(date +%s) - start) / 60 )) menit"

    if [ "$rc" -ne 0 ]; then
        err "Build gagal. Ini penyebabnya (kirim screenshot bagian ini):"
        local free_gb
        free_gb=$(df -BG --output=avail "$SRC" | tail -n 1 | tr -dc '0-9')
        echo "Sisa disk: ${free_gb:-?} GB"
        if [ "${free_gb:-0}" -lt 15 ]; then
            err "Disk hampir penuh: file hasil compile bisa terpotong/rusak. Kosongkan dulu (bash $SCRIPT bersih / clean)"
        fi
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

    local p="out/target/product/ingres" zip name
    zip=$(ls -t "$p"/Project_Infinity-X-*.zip 2>/dev/null | grep -v target_files | head -n 1)
    [ -n "$zip" ] || { err "Build selesai tapi zip Project_Infinity-X-*.zip tidak ditemukan"; exit 1; }
    name=$(basename "$zip")
    mkdir -p "$HASIL_DIR"
    cp "$zip" "$HASIL_DIR/$name"
    cp $p/boot.img $p/dtbo.img $p/vendor_boot.img $p/recovery.img "$HASIL_DIR"/ 2>/dev/null
    (cd "$HASIL_DIR" && sha256sum "$name" > "$name.sha256")
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
