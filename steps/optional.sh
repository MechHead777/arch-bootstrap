#!/usr/bin/env bash
# Offers optional packages without adding them to the unattended steps.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source-path=SCRIPTDIR source=../lib.sh
. "$repo/lib.sh"

for kind in gui tui; do
    list="$repo/packages/optional-$kind.txt"
    [ -f "$list" ] || die "missing package list: $list"
    mapfile -t packages < <(read_list "$list")
    info "Optional ${kind^^} applications"
    for index in "${!packages[@]}"; do
        printf '  %2d) %-20s' "$((index + 1))" "${packages[index]}"
        if (( (index + 1) % 4 == 0 )); then printf '\n'; fi
    done
    if (( ${#packages[@]} % 4 != 0 )); then printf '\n'; fi
    printf "\nNumbers to install, 'a' for all, Enter to skip: "
    read -r -a choices || die "could not read a selection"
    [ "${#choices[@]}" -gt 0 ] || continue
    selected=()
    if [ "${choices[*]}" = a ]; then
        selected=("${packages[@]}")
    else
        for number in "${choices[@]}"; do
            [[ "$number" =~ ^[1-9][0-9]*$ ]] && [ "$number" -le "${#packages[@]}" ] \
                || die "invalid selection: $number (expected 1-${#packages[@]})"
            selected+=("${packages[number - 1]}")
        done
    fi
    run sudo pacman -S --needed "${selected[@]}"
done
