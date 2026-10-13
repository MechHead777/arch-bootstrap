#!/usr/bin/env bash
# Applies the user configuration and CLI tools from the dotfiles repository.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source-path=SCRIPTDIR source=../lib.sh
. "$repo/lib.sh"

info "Dotfiles"
command -v mise >/dev/null || die "mise not found; run the packages step first"

if [ -d "$HOME/.local/share/chezmoi" ]; then
    run mise exec chezmoi -- chezmoi update
else
    run mise exec chezmoi -- chezmoi init --apply MechHead777/dotfiles
fi

printf 'Shell changes take effect in a new shell: exec zsh\n'
