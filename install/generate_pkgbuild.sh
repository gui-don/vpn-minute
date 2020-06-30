#!/usr/bin/env sh

current_path="$(dirname "$0")"
pkgver="$1"
pkgrel="$2"

tar -czf "vpn-minute-$pkgver.tar.gz" "$current_path/.."
b2sum=$(b2sum "vpn-minute-$pkgver.tar.gz" | cut -f 1 -d " ")

cp "$current_path/PKGBUILD.tpl" "PKGBUILD"
sed -i "s/<\#PKGVER>/$pkgver/g" "PKGBUILD"
sed -i "s/<\#PKGREL>/$pkgrel/g" "PKGBUILD"
sed -i "s/<\#B2SUM>/$b2sum/g" "PKGBUILD"
