#!/bin/sh
# Stage + tar the Arago client package from a build made by arago/build.sh.
#
# usage: package.sh BUILD_DIR OUT_DIR
# makes: OUT_DIR/mender-client-<ver>-arago-aarch64.tar.gz (+ .sha256)
#
# Layout (paths relative to /, owner root:root):
#   usr/bin/mender-update, usr/bin/mender-auth                                0755
#   usr/share/mender/modules/v3/{directory,single-file}                       0755
#   usr/share/mender/identity/mender-device-identity                          0755
#   usr/share/mender/inventory/mender-inventory-*                             0755
#   usr/lib/systemd/system/{mender-authd,mender-updated}.service              0644
#   usr/share/dbus-1/system.d/io.mender.AuthenticationManager.conf            0644
#   usr/share/dbus-1/system-services/io.mender.AuthenticationManager.service  0644
#   usr/share/mender-client-arago/{VERSION,MANIFEST.sha256}                   0644
# rootfs-image is left out on purpose: the SK image has no A/B (mender-flash +
# bootloader) integration, and the inventory would otherwise advertise it.
set -eu
BUILD=$(realpath "${1:?usage: package.sh BUILD_DIR OUT_DIR}")
OUT=${2:?usage: package.sh BUILD_DIR OUT_DIR}
SRC=$(cd "$(dirname "$0")/.." && pwd)
VERSION=${MENDER_VERSION:-5.2.0}
NAME=mender-client-$VERSION-arago-aarch64
STAGE=$OUT/stage/$NAME
mkdir -p "$OUT"; OUT=$(realpath "$OUT"); STAGE=$OUT/stage/$NAME
rm -rf "$OUT/stage"; mkdir -p "$STAGE"

d() { install -d -m 0755 "$STAGE/$1"; }
d usr/bin; d usr/share/mender/modules/v3; d usr/share/mender/identity; d usr/share/mender/inventory
d usr/lib/systemd/system; d usr/share/dbus-1/system.d; d usr/share/dbus-1/system-services
d usr/share/mender-client-arago

install -m 0755 "$BUILD/mender-update.stripped" "$STAGE/usr/bin/mender-update"
install -m 0755 "$BUILD/mender-auth.stripped"   "$STAGE/usr/bin/mender-auth"
for m in directory single-file; do
  install -m 0755 "$SRC/support/modules/$m" "$STAGE/usr/share/mender/modules/v3/$m"
done
install -m 0755 "$SRC/support/mender-device-identity" "$STAGE/usr/share/mender/identity/"
for i in provides hostinfo intervals network update-modules bootloader-integration os rootfs-type; do
  install -m 0755 "$SRC/support/mender-inventory-$i" "$STAGE/usr/share/mender/inventory/"
done
install -m 0644 "$SRC/support/mender-authd.service" "$SRC/support/mender-updated.service" \
  "$STAGE/usr/lib/systemd/system/"
install -m 0644 "$SRC/support/dbus/io.mender.AuthenticationManager.conf" "$STAGE/usr/share/dbus-1/system.d/"
install -m 0644 "$SRC/support/dbus/io.mender.AuthenticationManager.service" "$STAGE/usr/share/dbus-1/system-services/"

COMMIT=$(git -C "$SRC" rev-parse HEAD)
UPSTREAM=$(git -C "$SRC" rev-parse "$VERSION^{commit}" 2>/dev/null || echo unknown)
cat > "$STAGE/usr/share/mender-client-arago/VERSION" <<EOF
name=mender-client
version=$VERSION
upstream_tag=$VERSION
upstream_commit=$UPSTREAM
build_commit=$COMMIT
target=aarch64 TI Arago 2025.01 (PSDK 11.02, glibc 2.39)
dynamic=libc.so.6 ld-linux-aarch64.so.1 libssl.so.3 libcrypto.so.3 libdbus-1.so.3
EOF
chmod 0644 "$STAGE/usr/share/mender-client-arago/VERSION"

( cd "$STAGE" && find . -type f ! -name MANIFEST.sha256 | LC_ALL=C sort | sed 's|^\./||' | xargs sha256sum ) \
  > "$STAGE/usr/share/mender-client-arago/MANIFEST.sha256"
chmod 0644 "$STAGE/usr/share/mender-client-arago/MANIFEST.sha256"

TAR=$OUT/$NAME.tar.gz
# Reproducible: fixed owner, mtime from the build commit, sorted names.
MTIME=$(git -C "$SRC" log -1 --format=%cI)
tar -C "$STAGE" --sort=name --owner=0 --group=0 --numeric-owner --mtime="$MTIME" \
  --format=gnu -cf - usr | gzip -9n > "$TAR"
( cd "$OUT" && sha256sum "$NAME.tar.gz" > "$NAME.tar.gz.sha256" )
cat "$OUT/$NAME.tar.gz.sha256"
