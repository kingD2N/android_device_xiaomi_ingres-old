#!/usr/bin/env bash
#
# Build uwuAOSP 17 terbaru (Android 17, branch uwu-17.0, GApps Pixel bawaan)
# untuk POCO F4 GT (ingres) - satu perintah.
#
#   bash build-uwu.sh            # sync + build (otomatis jalan di byobu)
#   bash build-uwu.sh sync       # hanya sync source
#   bash build-uwu.sh build      # hanya build (lanjut dari build sebelumnya)
#   bash build-uwu.sh status     # lihat progres build yang sedang jalan
#   bash build-uwu.sh upload     # upload ulang isi ~/hasil-uwu ke GoFile
#   bash build-uwu.sh clean      # hapus hasil build lama (out/) lalu berhenti
#   bash build-uwu.sh bersih ~/axion   # hapus source ROM lain / folder lama
#   bash build-uwu.sh reset-ingres     # hapus repo ingres/xiaomi lama lalu sync ulang
#
# Pengaturan (opsional, isi sebelum perintah, contoh: VARIANT=userdebug bash build-uwu.sh):
#   SRC=~/uwu          folder source
#   JOBS=<angka>       jumlah job build (default: otomatis dari CPU & RAM)
#   RBE=1              pakai remote build (RBE) server (default: mati, compile lokal;
#                      hasil unduhan RBE di server ini berulang kali rusak)
#   VARIANT=user       user (rilis, default) / userdebug / eng
#   DECRYPT=0          /data terenkripsi seperti biasa (default: decrypt)
#   GOFILE=0           jangan upload hasil ke GoFile (default: upload otomatis)
#   GOFILE_TOKEN=xxx   token akun GoFile (opsional)

set -uo pipefail

ROM=uwu
ROM_NAME="uwuAOSP 17"
ROM_MANIFEST="https://github.com/uwuAOSP/platform_manifests"; ROM_BRANCH="uwu-17.0"
# fork repo uwuAOSP: fetch dangkal (--depth) yang terputus tidak mengunduh ulang seluruh history
REPO_ARGS=(--repo-url=https://github.com/UwUniverse/git-repo.git --repo-branch=main --no-repo-verify)
SRC="${SRC:-$HOME/uwu}"
VARIANT="${VARIANT:-user}"
SESSION="uwu"
LOG="$HOME/build-uwu.log"
MANIFEST_URL="https://raw.githubusercontent.com/kingD2N/android_device_xiaomi_ingres-old/uwu-17.0/local_manifests/uwu.xml"
HASIL_DIR="$HOME/hasil-uwu"
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
             "$HOME/aospa" "$HOME/build-aospa.log" \
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
    for s in los24 aospa lunaris axion ascp uwu; do
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
    envs="SRC='$SRC' VARIANT='$VARIANT' DECRYPT='${DECRYPT:-1}' GOFILE='${GOFILE:-1}' GOFILE_TOKEN='${GOFILE_TOKEN:-}' JOBS='${JOBS:-}' RBE='${RBE:-}'"
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
    local known d bak="$HOME/uwu-sisa-lama"
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
    local known d bak="$HOME/uwu-sisa-lama"
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

# uwuAOSP membuat image vendor lewat Soong (fsgen, uwu_ingres_generated_vendor_image).
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

unpatch_source() {
    git -C hardware/qcom-caf/sm8450/display checkout -q -- composer/hwc_display.cpp 2>/dev/null || true
    git -C vendor/xiaomi/gamekey checkout -q -- third_party/rust daemon/src 2>/dev/null || true
    local v
    for v in vendor/xiaomi/*/; do
        git -C "$v" checkout -q -- Android.bp ':(glob)*.mk' 2>/dev/null || true
    done
}
patch_source() {
    fix_fsgen_dupes
    fix_dolby_vision
    fix_gamekey
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
        [ -e "$f" ] && [ "$(basename "$f")" != uwu.xml ] && mv -f "$f" "$f.bak" && info "Menyingkirkan $(basename "$f")"
    done
    curl -fsSL -o .repo/local_manifests/uwu.xml "$MANIFEST_URL" || { err "Gagal unduh local manifest"; exit 1; }

    # sisa percobaan lama: folder ingres/xiaomi yang bukan hasil repo ini bikin
    # "unsupported checkout state" dan Android.bp lama (vendor common salah versi)
    reset_project() {
        local rel="${1#"$SRC"/}"; rel="${rel%/.git}"; rel="${rel%/}"
        case "$rel" in ""|/*|*..*) return ;; esac
        info "Menghapus checkout lama: $rel"
        rm -rf "${SRC:?}/$rel" "${SRC:?}/.repo/projects/$rel.git"
    }

    unpatch_source
    local n slog="$HOME/sync-uwu.log"
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
    # uwuAOSP: modul generator kernel ada di vendor/uwu (LineageOS: vendor/lineage)
    local g=out/soong/.intermediates/vendor/uwu/build/soong/generated_kernel_includes
    [ -d "$g" ] || return 0
    if [ -z "$(find "$g" -path '*usr/include/display/drm/sde_drm.h' -print -quit 2>/dev/null)" ] \
        || [ -z "$(find "$g" -path '*usr/include/audio/linux/msm_audio.h' -print -quit 2>/dev/null)" ]; then
        info "Header kernel tidak lengkap, dibuat ulang"
        rm -rf "$g"
    fi
}

# ----------------------------------------------------------------- build
# baca properti uwuAOSP dari build.prop hasil build; $@ = nama properti (yang pertama terisi)
uwu_prop() {
    local k f v
    for k in "$@"; do
        for f in out/target/product/ingres/product/etc/build.prop out/target/product/ingres/system/build.prop \
                 out/target/product/ingres/system_ext/etc/build.prop; do
            [ -f "$f" ] || continue
            v=$(grep -m1 "^$k=" "$f" | cut -d= -f2-)
            [ -n "$v" ] && { echo "$v"; return 0; }
        done
    done
    echo "UNOFFICIAL"
}

do_build() {
    cd "$SRC" 2>/dev/null && [ -f build/envsetup.sh ] || { err "Source belum ada. Jalankan: bash $SCRIPT sync"; exit 1; }
    # out/ dari build yang belum pernah selesai masih butuh banyak ruang
    if [ -s out/target/product/ingres/uwu_ingres-ota.zip ]; then check_disk 30
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
    set +u   # envsetup.sh / lunch memakai variabel yang belum diisi
    local start rc
    start=$(date +%s)
    info "ROM: $ROM_NAME"
    # shellcheck disable=SC1091
    source build/envsetup.sh >/dev/null
    # uwuAOSP: produk uwu_ingres; rilis (cp2a) diekspor envsetup dari build/release
    local rel="${aosp_target_release:-cp2a}"
    lunch "uwu_ingres-$rel-$VARIANT" || { err "lunch uwu_ingres-$rel-$VARIANT gagal (cek local manifest / sync)"; exit 1; }
    # RBE diatur SETELAH envsetup/lunch (vendorsetup.sh atau profil server bisa menyalakannya lagi)
    local rbe_state
    if [ "${RBE:-0}" != 1 ]; then
        # buang semua setelan RBE dari profil server (RBE_DIR, RBE_CXX_EXEC_STRATEGY, ...)
        # dan file konfigurasi env yang bisa mengisinya lagi
        local ev
        for ev in $(compgen -e | grep -E '^RBE_'); do unset "$ev"; done
        unset ANDROID_BUILD_ENVIRONMENT_CONFIG ANDROID_BUILD_ENVIRONMENT_CONFIG_DIR
        export USE_RBE=false USE_REWRAPPER=false NOSTART_RBE=true
        # server juga menyuntik rewrapper lewat CC_WRAPPER (dan JAVAC_WRAPPER) untuk
        # setiap compile C/C++; tanpa reproxy hasilnya "-server_address cannot be empty".
        # Buang bagian rewrapper, sisakan ccache kalau ada.
        local w v keep
        for w in CC_WRAPPER CXX_WRAPPER JAVAC_WRAPPER; do
            v="${!w:-}"
            case "$v" in
                *rewrapper*)
                    keep=$(printf '%s\n' "$v" | awk '{o=""; for(i=1;i<=NF;i++){if($i ~ /rewrapper/) break; o=o (o?" ":"") $i} print o}')
                    if [ -n "$keep" ]; then export "$w=$keep"; else unset "$w"; fi
                    info "$w tanpa rewrapper: ${keep:-(kosong)}" ;;
            esac
        done
        # Make (build/make/core/rbe.mk) memasang rewrapper ke CC_WRAPPER kalau
        # USE_REWRAPPER/RBE_DIR diisi di makefile, mis. buildspec.mk dari server:
        # nilai di makefile mengalahkan env, jadi singkirkan sementara
        if [ -f buildspec.mk ] && grep -qiE 'RBE|REWRAPPER' buildspec.mk; then
            mv -f buildspec.mk buildspec.mk.rbe-off
            info "buildspec.mk berisi setelan RBE: disingkirkan ke buildspec.mk.rbe-off"
        fi
        local rbe_mk
        rbe_mk=$(grep -rlsE '^[[:space:]]*(export[[:space:]]+)?(USE_RBE|USE_REWRAPPER|RBE_DIR)[[:space:]]*[:?+]?=' \
                 --include='*.mk' device vendor product 2>/dev/null | grep -v '^vendor/uwu/' | head -n 5)
        [ -n "$rbe_mk" ] && info "Makefile yang mengisi USE_RBE/USE_REWRAPPER/RBE_DIR: $(echo $rbe_mk)"
        rbe_state=off
        info "RBE mati: semua compile lokal (pakai RBE=1 untuk menyalakan)"
        info "Env build: $(env | grep -E '^(USE_RBE|USE_REWRAPPER|CC_WRAPPER|CXX_WRAPPER|JAVAC_WRAPPER|USE_CCACHE|CCACHE_EXEC)=' | tr '\n' ' ')"
    else
        [ -f buildspec.mk.rbe-off ] && [ ! -f buildspec.mk ] && mv -f buildspec.mk.rbe-off buildspec.mk
        rbe_state=on
        info "RBE server dipakai (RBE=1)"
    fi
    # aturan rewrapper tersimpan di file ninja Soong: kalau status RBE berganti,
    # paksa Soong membuat ulang file ninja supaya perintah compile ikut berubah
    rbe_state="$rbe_state ${CC_WRAPPER:-}"
    # juga kalau build lalu masih gagal karena rewrapper tanpa reproxy
    if [ "$(cat .rbe-ingres 2>/dev/null)" != "$rbe_state" ] || \
       { [ "${rbe_state%% *}" = off ] && [ -f "$LOG" ] && grep -q "server_address cannot be empty" "$LOG"; }; then
        rm -f out/soong/build.*.ninja out/soong/build.*.ninja.d 2>/dev/null
        info "Status RBE berganti (${rbe_state%% *}): file ninja Soong dibuat ulang"
    fi
    echo "$rbe_state" > .rbe-ingres
    # uwuAOSP tidak punya "m bacon": paket OTA dari m otapackage (uwu_ingres-ota.zip)
    m otapackage -j"$jobs" 2>&1 | tee "$LOG"
    rc=${PIPESTATUS[0]}
    if [ "${rbe_state%% *}" = off ] && grep -q "/rewrapper " "$LOG"; then
        err "Perintah build masih memakai rewrapper (RBE) walau RBE mati. Screenshot info di bawah ini:"
        {
        echo "--- env ---"; env | grep -iE '^(USE_RBE|USE_REWRAPPER|NOSTART_RBE|CC_WRAPPER|CXX_WRAPPER|JAVAC_WRAPPER|RBE_[A-Z_]*|ANDROID_BUILD_ENVIRONMENT_CONFIG[A-Z_]*)=' | cut -c1-160
        echo "--- rewrapper di ninja Soong: $(grep -c rewrapper out/soong/build.uwu_ingres.ninja 2>/dev/null || echo '?') baris"
        echo "--- env yang dipakai Soong ---"
        grep -hoE '"(USE_RBE|USE_REWRAPPER|CC_WRAPPER|RBE_WRAPPER)"[^,}]*' out/soong/soong.environment.used.uwu_ingres* 2>/dev/null | head -n 8 | cut -c1-160
        ls -la buildspec.mk* 2>/dev/null
        echo "--- makefile yang mengisi RBE ---"
        grep -rnsE '^[[:space:]]*(export[[:space:]]+)?(USE_RBE|USE_REWRAPPER|RBE_DIR|CC_WRAPPER)[[:space:]]*[:?+]?=' \
            --include='*.mk' buildspec.mk* device vendor product build/make/core 2>/dev/null \
            | grep -v -e 'core/rbe.mk' -e 'core/ccache.mk' | head -n 8 | cut -c1-160
        echo "--- CC_WRAPPER di ninja Soong ---"
        grep -m1 -o 'CcWrapper = .\{0,120\}' out/soong/build.uwu_ingres.ninja 2>/dev/null
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
    zip="$p/uwu_ingres-ota.zip"
    [ -s "$zip" ] || { err "Build selesai tapi $zip tidak ditemukan"; exit 1; }
    # nama rilis seperti "uni otapackage": uwuAOSP-<versi>-<tanggal>-<tipe>-ingres-unsigned.zip
    name="uwuAOSP-$(uwu_prop ro.uwu.release ro.uwu.build.version)-$(date -u +%Y%m%d)-$(uwu_prop ro.uwu.releasetype)-ingres-unsigned.zip"
    name="${name//[^A-Za-z0-9._-]/}"
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
