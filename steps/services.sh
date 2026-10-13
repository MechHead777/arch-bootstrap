#!/usr/bin/env bash
# Enables the network and container services.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source-path=SCRIPTDIR source=../lib.sh
. "$repo/lib.sh"

info "System services"

# Containers and chroots may have systemctl without a running systemd.
if [ "$(ps -p 1 -o comm=)" != systemd ]; then
    printf 'PID 1 is not systemd, skipping services\n'
    exit 0
fi

for service in NetworkManager.service docker.service; do
    if systemctl is-enabled --quiet "$service"; then
        printf '%s already enabled\n' "$service"
    else
        run sudo systemctl enable --now "$service"
    fi
done
