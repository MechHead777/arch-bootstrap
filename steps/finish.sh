#!/usr/bin/env bash
# Interactive GitHub setup for machines that need to push dotfiles changes.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source-path=SCRIPTDIR source=../lib.sh
. "$repo/lib.sh"

info "Finish: SSH and GitHub"
command -v gh >/dev/null || die "gh not found; apply the updated dotfiles and install their mise tools first"
command -v chezmoi >/dev/null || die "chezmoi not found; run the dotfiles step first"

key="$HOME/.ssh/id_ed25519"
machine="$(uname -n)"
if [ -f "$key" ]; then
    printf 'SSH key already exists: %s\n' "$key"
    [ -f "$key.pub" ] || die "public key missing: $key.pub; recover it before continuing"
else
    # An orphaned public key may belong to an existing key kept elsewhere.
    [ ! -e "$key.pub" ] || die "public key already exists without its private key: $key.pub"
    run mkdir -p -m 700 "$HOME/.ssh"
    run ssh-keygen -t ed25519 -C "$machine" -f "$key"
fi

if [ -n "${DRY_RUN:-}" ]; then
    run ssh-agent -s
elif ssh-add -l >/dev/null 2>&1; then
    printf 'SSH agent already available\n'
else
    agent_status=$?
    # Status 1 means a working agent with no keys; status 2 means no agent.
    if [ "$agent_status" -ne 1 ]; then
        agent_environment="$(run ssh-agent -s)"
        eval "$agent_environment"
        # An agent started in this child shell cannot serve the parent shell.
        trap 'run ssh-agent -k >/dev/null' EXIT
    fi
fi
run ssh-add "$key"

if [ -n "${DRY_RUN:-}" ] || ! gh auth status --hostname github.com >/dev/null 2>&1; then
    run gh auth login --hostname github.com --web --skip-ssh-key --scopes admin:public_key
else
    printf 'GitHub authentication already configured\n'
fi

if [ -n "${DRY_RUN:-}" ]; then
    run gh ssh-key add "$key.pub" --title "$machine"
else
    public_key="$(awk '{print $1 " " $2; exit}' "$key.pub")"
    registered_keys="$(gh api --hostname github.com --paginate user/keys --jq '.[].key')"
    if printf '%s\n' "$registered_keys" | grep -Fxq "$public_key"; then
        printf 'SSH key already registered with GitHub\n'
    else
        run gh ssh-key add "$key.pub" --title "$machine"
    fi
fi

remote=git@github.com:MechHead777/dotfiles.git
if [ "$(chezmoi git -- remote get-url origin)" = "$remote" ]; then
    printf 'Dotfiles remote already uses SSH\n'
else
    config="$(chezmoi git -- rev-parse --path-format=absolute --git-path config)"
    # Keep the previous Git configuration before switching the remote.
    run install -D -m 600 "$config" \
        "$HOME/.local/state/arch-bootstrap/dotfiles-git-config-$(date +%Y%m%d-%H%M%S).bak"
    run chezmoi git -- remote set-url origin "$remote"
fi

info "Verify GitHub SSH access (GitHub returns status 1 on success)"
ssh_status=0
run ssh -T git@github.com || ssh_status=$?
if [ "$ssh_status" -gt 1 ]; then
    warn "SSH verification failed (status $ssh_status); review the output above"
fi
