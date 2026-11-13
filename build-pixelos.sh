#!/usr/bin/env bash
#
# Build PixelOS (seventeen, Android 17) untuk POCO F4 GT (ingres) - satu perintah.
#
#   bash build-pixelos.sh            # sync + build (otomatis jalan di byobu)
#   bash build-pixelos.sh sync       # hanya sync source
#   bash build-pixelos.sh build      # hanya build (lanjut dari build sebelumnya)
#   bash build-pixelos.sh status     # lihat progres build yang sedang jalan
#   bash build-pixelos.sh upload     # upload ulang isi ~/hasil-pixelos ke GoFile
#   bash build-pixelos.sh clean      # hapus hasil build lama (out/) lalu berhenti
#   bash build-pixelos.sh bersih ~/aospa   # hapus source ROM lain / folder lama
#   bash build-pixelos.sh reset-ingres     # hapus repo ingres/xiaomi lama lalu sync ulang
#
# Pengaturan (opsional, isi sebelum perintah, contoh: VARIANT=userdebug bash build-pixelos.sh):
#   SRC=~/pixelos      folder source
#   JOBS=<angka>       jumlah job build (default: otomatis dari CPU & RAM)
#   VARIANT=user       user (rilis, default) / userdebug / eng
#   DECRYPT=0          /data terenkripsi seperti biasa (default: decrypt)
#   GOFILE=0           jangan upload hasil ke GoFile (default: upload otomatis)
#   GOFILE_TOKEN=xxx   token akun GoFile (opsional)

set -uo pipefail

ROM=pixelos
ROM_NAME="PixelOS 17"
ROM_MANIFEST="https://github.com/PixelOS-AOSP/android_manifest"; ROM_BRANCH="seventeen"
SRC="${SRC:-$HOME/pixelos}"
VARIANT="${VARIANT:-user}"
SESSION="pixelos"
LOG="$HOME/build-pixelos.log"
MANIFEST_URL="https://raw.githubusercontent.com/kingD2N/android_device_xiaomi_ingres-old/pixelos-17/local_manifests/pixelos.xml"
HASIL_DIR="$HOME/hasil-pixelos"
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
             "$HOME/uwu" "$HOME/infinity" "$HOME/ascp" "$HOME/aospa" "$HOME/axion" "$HOME/penguin" "$HOME/evox" "$HOME/hasil-evox" \
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
    for s in los24 aospa lunaris uwu infinity ascp evox pixelos; do
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
    envs="SRC='$SRC' VARIANT='$VARIANT' DECRYPT='${DECRYPT:-1}' GOFILE='${GOFILE:-1}' GOFILE_TOKEN='${GOFILE_TOKEN:-}' JOBS='${JOBS:-}'"
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
    local known d bak="$HOME/pixelos-sisa-lama"
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
    local known d bak="$HOME/pixelos-sisa-lama"
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

unpatch_source() {
    git -C hardware/qcom-caf/sm8450/display checkout -q -- composer/hwc_display.cpp 2>/dev/null || true
    git -C vendor/xiaomi/gamekey checkout -q -- third_party/rust daemon/src 2>/dev/null || true
}
patch_source() {
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
        [ -e "$f" ] && [ "$(basename "$f")" != pixelos.xml ] && mv -f "$f" "$f.bak" && info "Menyingkirkan $(basename "$f")"
    done
    curl -fsSL -o .repo/local_manifests/pixelos.xml "$MANIFEST_URL?$(date +%s)" || { err "Gagal unduh local manifest"; exit 1; }

    # sisa percobaan lama: folder ingres/xiaomi yang bukan hasil repo ini bikin
    # "unsupported checkout state" dan Android.bp lama (vendor common salah versi)
    reset_project() {
        local rel="${1#"$SRC"/}"; rel="${rel%/.git}"; rel="${rel%/}"
        case "$rel" in ""|/*|*..*) return ;; esac
        info "Menghapus checkout lama: $rel"
        rm -rf "${SRC:?}/$rel" "${SRC:?}/.repo/projects/$rel.git"
    }

    unpatch_source
    local n slog="$HOME/sync-pixelos.log"
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
    if [ "${DECRYPT:-1}" = 0 ]; then export TARGET_DECRYPTED_DATA=false; info "/data terenkripsi"; else export TARGET_DECRYPTED_DATA=true; info "/data tanpa enkripsi (decrypt)"; fi
    set +u   # envsetup.sh / breakfast memakai variabel yang belum diisi
    local start rc
    start=$(date +%s)
    info "ROM: $ROM_NAME"
    # shellcheck disable=SC1091
    source build/envsetup.sh >/dev/null
    mkdir -p "$HASIL_DIR"
    build_rom "$jobs"
    echo "Durasi total: $(( ($(date +%s) - start) / 60 )) menit"
    ok "BUILD BERHASIL"
    ls -lh "$HASIL_DIR"
    if [ "${GOFILE:-1}" != 0 ]; then
        do_upload || echo "Upload GoFile gagal. Ulangi dengan: bash $SCRIPT upload"
    else
        echo "Ambil file di folder $HASIL_DIR lewat SFTP Termius."
    fi
}

# Build ROM: $1 = jumlah job (PixelOS selalu membawa GApps)
build_rom() {
    local jobs="$1" rc vstart name="PixelOS"
    vstart=$(date +%s)
    info "Build $name"
    lunch "lineage_ingres-cp2a-$VARIANT" || { err "lunch lineage_ingres-cp2a-$VARIANT gagal (cek local manifest / sync)"; exit 1; }
    m pixelos -j"$jobs" 2>&1 | tee "$LOG"
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
    zip=$(ls -t "$p"/PixelOS_*ingres*.zip 2>/dev/null | grep -v target_files | head -n 1)
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
