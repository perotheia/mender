#!/bin/sh
# Cross-build mender-update + mender-auth for TI Arago 2025.01 (PSDK 11.02) aarch64.
#
# usage: build.sh SYSROOT BUILD_DIR
#   SYSROOT    made by arago/make-sysroot.sh (Debian bookworm arm64, glibc 2.36)
#   BUILD_DIR  out-of-tree build directory
#
# Static: libstdc++/libgcc, Boost 1.74 (log/thread/filesystem...), libarchive 3.8.4
#         (built from source, gzip/xz/zstd only), lmdb, zlib, liblzma, libzstd,
#         yaml-cpp + nlohmann-json + tiny-process-library (vendored).
# Dynamic: glibc (libc, libm, ld-linux), libssl.so.3 + libcrypto.so.3, libdbus-1.so.3.
set -eu
SYSROOT=$(realpath "${1:?usage: build.sh SYSROOT BUILD_DIR}")
BUILD=${2:?usage: build.sh SYSROOT BUILD_DIR}
SRC=$(cd "$(dirname "$0")/.." && pwd)
VERSION=${MENDER_VERSION:-5.2.0}
JOBS=${JOBS:-6}   # taycann resource rule: at most -j6

mkdir -p "$BUILD"; BUILD=$(realpath "$BUILD")
aarch64-linux-gnu-gcc -Os -nostdinc -isystem /usr/lib/gcc-cross/aarch64-linux-gnu/11/include \
  -isystem "$SYSROOT/usr/include/aarch64-linux-gnu" -isystem "$SYSROOT/usr/include" \
  -c "$SRC/arago/isoc23-shim.c" -o "$BUILD/isoc23-shim.o"

cmake -S "$SRC" -B "$BUILD" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$SRC/arago/toolchain-arago-aarch64.cmake" \
  -DARAGO_SYSROOT="$SYSROOT" \
  -DCMAKE_BUILD_TYPE=MinSizeRel \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DSYSTEMD_UNIT_DIR=/usr/lib/systemd/system \
  -DMENDER_VERSION="$VERSION" \
  -DBUILD_TESTS=OFF \
  -DCMAKE_CXX_STANDARD_LIBRARIES="$BUILD/isoc23-shim.o" \
  -DBoost_USE_STATIC_LIBS=ON \
  -DMENDER_FORCE_DOWNLOAD_LIBARCHIVE=ON \
  -DENABLE_OPENSSL=OFF -DENABLE_MBEDTLS=OFF -DENABLE_NETTLE=OFF -DENABLE_LIBB2=OFF \
  -DENABLE_LZ4=OFF -DENABLE_LZO=OFF -DENABLE_BZip2=OFF -DENABLE_LIBXML2=OFF -DENABLE_EXPAT=OFF \
  -DENABLE_PCREPOSIX=OFF -DENABLE_PCRE2POSIX=OFF -DENABLE_LIBGCC=OFF -DENABLE_CNG=OFF \
  -DENABLE_ACL=OFF -DENABLE_ICONV=OFF \
  -DENABLE_ZLIB=ON -DENABLE_LZMA=ON -DENABLE_ZSTD=ON

cmake --build "$BUILD" --target mender-update mender-auth -- -j"$JOBS"
aarch64-linux-gnu-strip -o "$BUILD/mender-update.stripped" "$BUILD/src/mender-update/mender-update"
aarch64-linux-gnu-strip -o "$BUILD/mender-auth.stripped" "$BUILD/src/mender-auth/mender-auth"
echo "built: $BUILD/src/mender-update/mender-update $BUILD/src/mender-auth/mender-auth"
