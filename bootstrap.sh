#!/usr/bin/env bash
# Runs the workstation steps in order, or reports package drift.
set -euo pipefail
set -E

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$repo/lib.sh"

[ "$(id -u)" -ne 0 ] || die "run as your user, not root"

steps=(packages system services dotfiles devpod)
skip=
check=
case "${1:-}" in
    '') [ "$#" -eq 0 ] || die "unexpected empty argument" ;;
    finish) [ "$#" -eq 1 ] || die "usage: ./bootstrap.sh finish"; steps=(finish) ;;
    --only|--skip)
        [ "$#" -eq 2 ] || die "usage: ./bootstrap.sh $1 <step>"
        case "$2" in
            packages|system|services|dotfiles|devpod|optional|finish) ;;
            *) die "unknown step: $2" ;;
        esac
        if [ "$1" = --only ]; then steps=("$2"); else skip="$2"; fi
        ;;
    --check) [ "$#" -eq 1 ] || die "usage: ./bootstrap.sh --check"; check=1 ;;
    *) die "usage: ./bootstrap.sh [finish | --only <step> | --skip <step> | --check]" ;;
esac

if [ -n "$check" ]; then
    profile="$(detect_profile)"
    info "Package drift (profile: $profile)"
    lists=("$repo/packages/base.txt")
    case "$profile" in
        laptop) lists+=("$repo/packages/desktop.txt" "$repo/packages/laptop.txt") ;;
        desktop) lists+=("$repo/packages/desktop.txt") ;;
        base) ;;
        *) die "unknown profile: $profile (expected base, desktop, or laptop)" ;;
    esac
    for list in "${lists[@]}" "$repo/packages/optional-gui.txt" "$repo/packages/optional-tui.txt"; do
        [ -f "$list" ] || die "missing package list: $list"
    done
    declared="$(for list in "${lists[@]}"; do read_list "$list"; done | sort -u)"
    installed="$(pacman -Qqe | sort -u)"
    ignored="$(
        { read_list "$repo/packages/optional-gui.txt"
          read_list "$repo/packages/optional-tui.txt"
          printf '%s\n' intel-ucode amd-ucode
        } | sort -u
    )"
    mapfile -t missing < <(comm -23 <(printf '%s\n' "$declared") <(printf '%s\n' "$installed"))
    mapfile -t extra < <(
        comm -23 <(comm -13 <(printf '%s\n' "$declared") <(printf '%s\n' "$installed")) \
            <(printf '%s\n' "$ignored")
    )
    info "Declared but not installed"
    if [ "${#missing[@]}" -gt 0 ]; then
        printf '  %s\n' "${missing[@]}"
        printf 'Install: sudo pacman -Syu --needed'
        printf ' %q' "${missing[@]}"
        printf '\n'
    else
        printf 'None\n'
    fi
    info "Installed but not declared"
    if [ "${#extra[@]}" -gt 0 ]; then
        printf '  %s\n' "${extra[@]}"
        printf 'Add wanted packages to the appropriate list, or review this manual removal command:\n'
        printf 'sudo pacman -Rns'
        printf ' %q' "${extra[@]}"
        printf '\n'
    else
        printf 'None\n'
    fi
    exit 0
fi

for step in "${steps[@]}"; do
    [ "$step" = "$skip" ] && continue
    [ -f "$repo/steps/$step.sh" ] || die "missing step: $repo/steps/$step.sh"
done

log='not written (dry run)'
sudo_pid=
if [ -z "${DRY_RUN:-}" ]; then
    log="$HOME/.local/state/arch-bootstrap/$(date +%y%m%d-%H%M%S)-$$.log"
    run mkdir -p "$(dirname "$log")"
    exec > >(tee -a "$log") 2>&1
    printf 'Log: %s\n' "$log"
fi
trap 'printf "Failed at %s:%s. Log: %s\n" "${BASH_SOURCE[0]}" "$LINENO" "$log" >&2' ERR
trap 'if [ -n "$sudo_pid" ]; then kill "$sudo_pid" 2>/dev/null || true; wait "$sudo_pid" 2>/dev/null || true; fi' EXIT

run sudo -v
if [ -z "${DRY_RUN:-}" ]; then
    while sudo -n true; do sleep 50; done >/dev/null 2>&1 &
    sudo_pid=$!
fi

for step in "${steps[@]}"; do
    [ "$step" = "$skip" ] && continue
    info "Step: $step"
    (
        # Each step has its own variables and may exit without ending the runner.
        trap - EXIT
        # shellcheck source=/dev/null
        . "$repo/steps/$step.sh"
    )
done

info "Bootstrap complete"
