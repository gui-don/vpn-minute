#!/usr/bin/env sh

local current_path=$(dirname "$(readlink -f "$0")")
local pkgver="$1"
local pkgrel="$2"
local b2sum="$3"

sed -i "s/\<\#PKGVER\>/$pkgver/g" "$current_path/PKGBUILD"
sed -i "s/\<\#PKGREL\>/$pkgrel/g" "$current_path/PKGBUILD"
sed -i "s/\<\#B2SUM\>/$b2sum/g" "$current_path/PKGBUILD"
