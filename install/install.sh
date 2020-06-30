#!/usr/bin/env sh

current_path="$(dirname "$0")"
pkgdir="$1"
pkgname="$2"

echo $(ls "$current_path"/../)

install -Dm644 README.md "$pkgdir/usr/share/doc/${pkgname}/README.md"

install -Dm755 main.sh "$pkgdir/usr/bin/vpnm"

find "$current_path/../terraform" -type d -exec install -d "$pkgdir/usr/share/$pkgname/{}" \;
find "$current_path/../terraform" -type f -iname "*.tmpl" -exec install -Dm444 "{}" "$pkgdir/usr/share/$pkgname/{}" \;
find "$current_path/../terraform" -type f -iname "*.tf" -exec install -Dm444 "{}" "$pkgdir/usr/share/$pkgname/{}" \;
