#!/bin/sh
# Build sysroot for the Arago (TI PSDK 11.02, glibc 2.39) cross build of the
# Mender client: Debian bookworm arm64 (glibc 2.36), headers + static archives.
#
# usage: make-sysroot.sh DIR
#
# Needs: debootstrap, qemu-aarch64-static (binfmt), sudo.
set -eu
DIR=${1:?usage: make-sysroot.sh DIR}
MIRROR=${MIRROR:-http://deb.debian.org/debian}

PKGS=libc6-dev,libstdc++-12-dev,libssl-dev,libdbus-1-dev,liblmdb-dev,zlib1g-dev,liblzma-dev,libzstd-dev
PKGS=$PKGS,libboost1.74-dev,libboost-log1.74-dev,libboost-thread1.74-dev,libboost-filesystem1.74-dev
PKGS=$PKGS,libboost-regex1.74-dev,libboost-atomic1.74-dev,libboost-chrono1.74-dev,libboost-date-time1.74-dev
PKGS=$PKGS,pkg-config

if [ ! -e "$DIR/debootstrap" ] && [ ! -e "$DIR/usr/bin/dpkg" ]; then
  sudo debootstrap --arch=arm64 --foreign --variant=minbase --include=$PKGS bookworm "$DIR" "$MIRROR"
fi
if [ -e "$DIR/debootstrap" ]; then
  sudo cp /usr/bin/qemu-aarch64-static "$DIR/usr/bin/"
  sudo chroot "$DIR" /debootstrap/debootstrap --second-stage
fi

# Absolute symlinks (libfoo.so -> /lib/...) break outside the chroot: make them relative.
sudo find "$DIR/usr/lib/aarch64-linux-gnu" "$DIR/lib" -maxdepth 2 -type l -lname '/*' 2>/dev/null |
while read -r l; do
  t=$(readlink "$l")
  sudo ln -sfn "$(realpath -m --relative-to="$(dirname "$l")" "$DIR$t")" "$l"
done

# Everything except the base system libraries is linked statically, so the
# binaries do not depend on which TI image variant (default/adas/edgeai) is on
# the board: hide the .so dev links so only the .a can be found. lmdb is on no
# Arago image; boost/zlib/xz/zstd are on the adas image but in other versions.
# Kept dynamic: libc family, libssl/libcrypto (openssl 3), libdbus-1 -- present
# on the TI rootfs tisdk-adas-image-j721e-evm 11.02.02.05 (libssl3 3.5.7,
# libdbus-1-3 1.14.10, libc6 2.39).
L="$DIR/usr/lib/aarch64-linux-gnu"
for so in liblmdb.so libz.so liblzma.so libzstd.so "libboost_*.so"; do
  for f in $L/$so; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    sudo rm -f "$f"
  done
done
sudo chown -R "$(id -u):$(id -g)" "$DIR/usr/lib/aarch64-linux-gnu/pkgconfig" 2>/dev/null || true
echo "sysroot ready: $DIR"
