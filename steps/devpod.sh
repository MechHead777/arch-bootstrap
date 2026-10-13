#!/usr/bin/env bash
# Installs DevPod and configures its Docker provider and dotfiles options.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source-path=SCRIPTDIR source=../lib.sh
. "$repo/lib.sh"

info "DevPod"
devpod="$(command -v devpod || true)"

if [ -n "$devpod" ]; then
    printf 'DevPod already installed: %s\n' "$devpod"
else
    # Neither the official Arch repos nor the mise registry provides DevPod.
    version=v0.6.15
    case "$(uname -m)" in
        x86_64) arch=amd64 ;;
        aarch64) arch=arm64 ;;
        *) die "unsupported DevPod architecture: $(uname -m)" ;;
    esac
    command -v curl >/dev/null || die "curl not found; install curl first"
    devpod="$HOME/.local/bin/devpod"
    download="$(mktemp)"
    trap 'rm -f "$download"' EXIT
    run mkdir -p "$HOME/.local/bin"
    run curl -fL --output "$download" \
        "https://github.com/loft-sh/devpod/releases/download/$version/devpod-linux-$arch"
    run install -m 755 "$download" "$devpod"
fi

# Group changes from the system step take effect only after a new login.
if ! id -nG | grep -qw docker; then
    warn "docker group is not active; log out and back in, then rerun the DevPod step"
    exit 0
fi

providers='{}'
if command -v "$devpod" >/dev/null; then
    providers="$("$devpod" provider list --output json)"
fi
if printf '%s\n' "$providers" | grep -q '"docker"[[:space:]]*:'; then
    printf 'Docker provider already configured\n'
else
    run "$devpod" provider add docker
fi

run "$devpod" provider use docker
run "$devpod" ide use none
run "$devpod" context set-options \
    -o DOTFILES_URL=https://github.com/MechHead777/dotfiles \
    -o DOTFILES_SCRIPT=setup \
    -o SSH_AGENT_FORWARDING=true \
    -o SSH_ADD_PRIVATE_KEYS=true
