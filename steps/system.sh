#!/usr/bin/env bash
# System configuration: pacman settings, zram, sudo, and the docker group.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source-path=SCRIPTDIR source=../lib.sh
. "$repo/lib.sh"

# ETC_ROOT exists so this step can be tested against a scratch directory.
etc="${ETC_ROOT:-/etc}"

info "System configuration"

# pacman.conf is edited in place rather than replaced, so upstream changes to
# the file are kept and no .pacnew file is created.
configure_pacman() {
    local conf="$etc/pacman.conf" tmp
    [ -f "$conf" ] || { warn "no $conf, skipping pacman settings"; return; }

    tmp="$(mktemp)"
    sed -e 's/^#Color$/Color/' \
        -e 's/^#\?ParallelDownloads *=.*/ParallelDownloads = 5/' \
        "$conf" >"$tmp"
    grep -q '^ILoveCandy' "$tmp" || sed -i '/^\[options\]/a ILoveCandy' "$tmp"

    if cmp -s "$tmp" "$conf"; then
        printf 'pacman.conf already configured\n'
    else
        diff -u "$conf" "$tmp" || true
        run sudo install -m 644 "$tmp" "$conf"
    fi
    rm -f "$tmp"
}

# install_file <mode> <source> <destination>
install_file() {
    local mode="$1" src="$2" dest="$3"
    [ -f "$src" ] || die "missing source file: $src"

    # sudoers files are readable only by root, even when already correct.
    if sudo cmp -s "$src" "$dest" 2>/dev/null; then
        printf '%s already up to date\n' "$dest"
    else
        run sudo install -D -m "$mode" "$src" "$dest"
    fi
}

configure_sudo() {
    local src="$repo/system/10-wheel"
    if command -v visudo >/dev/null; then
        sudo visudo -cf "$src" >/dev/null || die "sudoers file failed validation: $src"
    else
        warn "visudo not found, installing the sudoers file unchecked"
    fi
    install_file 440 "$src" "$etc/sudoers.d/10-wheel"
}

# Members of the docker group can start containers as root, which is
# equivalent to root on this machine.
configure_docker_group() {
    local user; user="$(id -un)"
    if id -nG | grep -qw docker; then
        printf '%s is already in the docker group\n' "$user"
    else
        run sudo usermod -aG docker "$user"
        warn "log out and back in for the docker group to take effect"
    fi
}

configure_pacman
install_file 644 "$repo/system/zram-generator.conf" "$etc/systemd/zram-generator.conf"
configure_sudo
configure_docker_group
