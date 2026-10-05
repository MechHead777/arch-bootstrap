# Shared helpers. Sourced by bootstrap.sh and by each step.
# shellcheck shell=bash

info() { printf '\n== %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# run <command...>  — runs it, or prints it when DRY_RUN is set.
run() {
  if [ -n "${DRY_RUN:-}" ]; then
    printf 'would run: %s\n' "$*"
  else
    "$@"
  fi
}

# read_list <file>  — prints one package per line, comments and blanks removed.
read_list() {
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | grep . || true
}

# detect_profile  — prints base, desktop, or laptop.
detect_profile() {
  if [ -n "${PROFILE:-}" ]; then
    printf '%s\n' "$PROFILE"
  elif compgen -G '/sys/class/power_supply/BAT*' >/dev/null; then
    printf 'laptop\n'
  elif systemd-detect-virt --quiet 2>/dev/null; then
    printf 'base\n'
  else
    printf 'desktop\n'
  fi
}

# detect_microcode  — prints intel-ucode, amd-ucode, or nothing.
detect_microcode() {
  case "$(awk -F': ' '/^vendor_id/ {print $2; exit}' /proc/cpuinfo)" in
  GenuineIntel) printf 'intel-ucode\n' ;;
  AuthenticAMD) printf 'amd-ucode\n' ;;
  *) warn "unrecognized CPU vendor, skipping microcode" ;;
  esac
}
