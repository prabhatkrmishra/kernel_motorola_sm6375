#!/usr/bin/env bash
# Kernel build script for fogos (msm-5.4, holi/qgki)

set -uo pipefail

ROOT_PATH="$(pwd)"
OUTPUT_DIRECTORY_PATH="$ROOT_PATH/out"

#============== Build specific variables ==============#
BUILD_CONFIG="kernel/msm-5.4/build.config.msm.holi"
BUILD_VARIANT="qgki"
BUILD_TARGET_PRODUCT="fogos"
CLANG_LTO_TYPE="thin"

# Toolchain: aosp | sdclang
# override using: TOOLCHAIN=sdclang ./build_kernel.sh
TOOLCHAIN="${TOOLCHAIN:-aosp}"
JOBS="$(( $(nproc) > 1 ? $(nproc) - 1 : 1 ))"

#============== Helpers ==============#
die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: $0 (--new | --rebuild) [-j N] [-h]

  --new       Full clean build (wipes out/, runs mrproper + defconfig)
  --rebuild   Incremental build, skips mrproper
  -j N        Parallel jobs (default: $JOBS)
  -h, --help  Show this help

Env: TOOLCHAIN=aosp|sdclang (default: aosp)
EOF
}

#============== Argument Handler ==============#
MODE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --new)
            MODE="new"
            ;;
        --rebuild)
            MODE="rebuild"
            ;;
        -j)
            [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]] || die "-j needs a number"
            JOBS="$2"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Invalid option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

# A build mode is mandatory
if [[ -z "$MODE" ]]; then
    echo "Error: specify --new or --rebuild" >&2
    usage >&2
    exit 1
fi

case "$MODE" in
    new)
        rm -rf "$OUTPUT_DIRECTORY_PATH"
        ;;
    rebuild)
        export SKIP_MRPROPER=1
        ;;
esac

mkdir -p "$OUTPUT_DIRECTORY_PATH"

export TARGET_BUILD_VARIANT=user
export KERNEL_BUILD_MODE=user
export ARCH=arm64
export SUBARCH=arm64
export HEADER_ARCH=arm64

# Keeps timestamps stable between builds
export SOURCE_DATE_EPOCH=1717300000

#============== LLVM TOOLCHAIN ==============#
case "$TOOLCHAIN" in
    aosp)
        # AOSP clang v20.0.0
        LLVM_DIR="$ROOT_PATH/prebuilts-master/clang/host/linux-x86/clang-r547379/bin"
        ;;
    sdclang)
        # Qualcomm Snapdragon LLVM 19.0.0
        LLVM_DIR="$ROOT_PATH/sdclang-19.0.0/bin"
        ;;
    *)
        die "Unknown TOOLCHAIN '$TOOLCHAIN' (use aosp or sdclang)"
        ;;
esac

[[ -x "$LLVM_DIR/clang" ]] || die "clang not found at $LLVM_DIR"
[[ -x "$ROOT_PATH/build/build.sh" ]] || die "build/build.sh not found; run from the source root"
export LLVM_DIR
export PATH="$LLVM_DIR:$PATH"

echo ">>> Toolchain : $TOOLCHAIN ($("$LLVM_DIR/clang" --version | head -n1))"
echo ">>> Mode      : $MODE  | LTO: $CLANG_LTO_TYPE | jobs: $JOBS"

#============== BUILD ==============#
BUILD_START=$SECONDS

BUILD_CONFIG="$BUILD_CONFIG" \
VARIANT="$BUILD_VARIANT" \
LTO="$CLANG_LTO_TYPE" \
TARGET_PRODUCT="$BUILD_TARGET_PRODUCT" \
BUILD_KERNEL=1 \
build/build.sh \
    LLVM_IAS=0 \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
    HOSTCC="$LLVM_DIR/clang" \
    HOSTCXX="$LLVM_DIR/clang++" \
    HOSTLD="$LLVM_DIR/ld.lld" \
    HOSTAR="$LLVM_DIR/llvm-ar" \
    HOSTLDFLAGS="-fuse-ld=lld" \
    CC="$LLVM_DIR/clang" \
    AS="aarch64-linux-gnu-as" \
    LD="$LLVM_DIR/ld.lld" \
    AR="$LLVM_DIR/llvm-ar" \
    NM="$LLVM_DIR/llvm-nm" \
    OBJCOPY="$LLVM_DIR/llvm-objcopy" \
    OBJDUMP="$LLVM_DIR/llvm-objdump" \
    READELF="$LLVM_DIR/llvm-readelf" \
    OBJSIZE="$LLVM_DIR/llvm-size" \
    STRIP="$LLVM_DIR/llvm-strip" \
    LLVM_AR="$LLVM_DIR/llvm-ar" \
    LLVM_NM="$LLVM_DIR/llvm-nm" \
    -j"$JOBS"
BUILD_RC=$?

ELAPSED=$(( SECONDS - BUILD_START ))
printf '>>> Build time: %dm %ds\n' $((ELAPSED / 60)) $((ELAPSED % 60))

#============== COPY BINARIES ==============#
copy_file() {
    local src="$1" dst="$2"
    [[ -f "$src" ]] || { echo " Missing: $src" >&2; return 1; }
    cp -f "$src" "$dst"
}

copy_binaries() {
    local boot_dir="$OUTPUT_DIRECTORY_PATH/msm-5.4-holi-qgki/kernel/msm-5.4/arch/arm64/boot"
    local dtb_dir="$boot_dir/dts/vendor/qcom"
    local rc=0

    echo " Copying kernel binaries"
    copy_file "$boot_dir/Image"    "$OUTPUT_DIRECTORY_PATH/Image"    || rc=1
    copy_file "$boot_dir/Image.gz" "$OUTPUT_DIRECTORY_PATH/Image.gz" || rc=1
    echo " KERNEL binaries copied to out"

    copy_file "$dtb_dir/blair-moto-fogos-base.dtb" "$OUTPUT_DIRECTORY_PATH/blair-moto-fogos-base.dtb" || rc=1
    echo " DTB copied to out"

    local dtbo
    for dtbo in blair-fogos-dvt1-overlay.dtbo blair-fogos-evt-overlay.dtbo; do
        copy_file "$dtb_dir/$dtbo" "$OUTPUT_DIRECTORY_PATH/$dtbo" || rc=1
    done
    echo " DTBO files copied to out"

    return $rc
}

#============== BUILD RESULT ==============#
IMAGE_GZ="$OUTPUT_DIRECTORY_PATH/msm-5.4-holi-qgki/kernel/msm-5.4/arch/arm64/boot/Image.gz"

echo
if [[ $BUILD_RC -eq 0 && -f "$IMAGE_GZ" ]] && copy_binaries; then
    echo " Kernel build successful!"
    echo " Output: $OUTPUT_DIRECTORY_PATH"
    exit 0
else
    echo " Kernel build failed! (build.sh exit code: $BUILD_RC)" >&2
    exit 1
fi
