#!/usr/bin/env bash
# Installs the declared packages for this machine's profile.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source-path=SCRIPTDIR source=../lib.sh
. "$repo/lib.sh"

profile="$(detect_profile)"
info "Packages (profile: $profile)"

lists=("$repo/packages/base.txt")
case "$profile" in
laptop) lists+=("$repo/packages/desktop.txt" "$repo/packages/laptop.txt") ;;
desktop) lists+=("$repo/packages/desktop.txt") ;;
base) ;;
*) die "unknown profile: $profile (expected base, desktop, or laptop)" ;;
esac

for list in "${lists[@]}"; do
  [ -f "$list" ] || die "missing package list: $list"
done

packages=()
for list in "${lists[@]}"; do
  mapfile -t -O "${#packages[@]}" packages < <(read_list "$list")
done
mapfile -t -O "${#packages[@]}" packages < <(detect_microcode)

[ "${#packages[@]}" -gt 0 ] || die "no packages to install"
printf '%s packages: %s\n' "${#packages[@]}" "${packages[*]}"

# -Syu rather than -S: Arch does not support partial upgrades, so the package
# databases and the system are updated in the same transaction.
run sudo pacman -Syu --needed --noconfirm "${packages[@]}"
