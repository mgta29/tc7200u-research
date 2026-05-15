#!/usr/bin/env bash
set -euo pipefail

OWRT="${OWRT:-$HOME/src/openwrt}"

TC7200U_DEBUG_PACKAGES_DEFAULT="ethtool ip-full mtd nand-utils ubi-utils block-mount blkid lsblk dtc strace tcpdump"
TC7200U_DRIVER_PACKAGES_DEFAULT="kmod-bgmac-b53 kmod-dsa-core kmod-mdio-bcm-unimac"

TC7200U_DEBUG_PACKAGES="${TC7200U_DEBUG_PACKAGES:-$TC7200U_DEBUG_PACKAGES_DEFAULT}"
TC7200U_EXTRA_DEBUG_PACKAGES="${TC7200U_EXTRA_DEBUG_PACKAGES:-}"
TC7200U_DRIVER_PACKAGES="${TC7200U_DRIVER_PACKAGES:-$TC7200U_DRIVER_PACKAGES_DEFAULT}"
TC7200U_INCLUDE_DRIVER_PACKAGES="${TC7200U_INCLUDE_DRIVER_PACKAGES:-0}"

cd "$OWRT"

if [ ! -f .config ]; then
	echo "FAIL: missing OpenWrt .config in $OWRT" >&2
	exit 1
fi

packages="$TC7200U_DEBUG_PACKAGES $TC7200U_EXTRA_DEBUG_PACKAGES"

if [ "$TC7200U_INCLUDE_DRIVER_PACKAGES" = "1" ]; then
	packages="$packages $TC7200U_DRIVER_PACKAGES"
fi

packages="$(printf '%s\n' $packages | awk 'NF && !seen[$0]++ { print }')"

if [ -z "$packages" ]; then
	echo "INFO: no TC7200U debug packages requested"
	exit 0
fi

tmp_config="$(mktemp)"
cp .config "$tmp_config"

while IFS= read -r pkg; do
	[ -n "$pkg" ] || continue
	awk -v opt="CONFIG_PACKAGE_${pkg}" '$0 != opt"=y" && $0 != "# "opt" is not set" { print }' "$tmp_config" > "$tmp_config.next"
	mv "$tmp_config.next" "$tmp_config"
	echo "CONFIG_PACKAGE_${pkg}=y" >> "$tmp_config"
done <<EOF_PACKAGES
$packages
EOF_PACKAGES

cp "$tmp_config" .config
rm -f "$tmp_config"

echo "== TC7200U debug package config =="
echo "OWRT=$OWRT"
echo "TC7200U_INCLUDE_DRIVER_PACKAGES=$TC7200U_INCLUDE_DRIVER_PACKAGES"

make defconfig

echo
missing=0

while IFS= read -r pkg; do
	[ -n "$pkg" ] || continue
	if grep -qx "CONFIG_PACKAGE_${pkg}=y" .config; then
		echo "enabled:   $pkg"
	else
		echo "WARN: not enabled after defconfig: $pkg" >&2
		missing=1
	fi
done <<EOF_PACKAGES
$packages
EOF_PACKAGES

if [ "$missing" = "1" ]; then
	echo "WARN: at least one package was not selected. Check feeds/package name availability." >&2
fi

echo "OK: OpenWrt .config updated for TC7200U debug image packages"
