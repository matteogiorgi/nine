#!/bin/sh
# uninstall -- remove everything nine installed.
# Executable transcription of the Uninstall section in README.md.
# Does nothing that section does not explain.
# POSIX sh; validated with: shfmt -ln posix

set -eu

PLAN9_DIR="$HOME/plan9"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
PROFILE="$HOME/.profile"
LINKS="9 acme sam 9term win fontsrv plumb 9pserve devdraw 9pfuse samterm nine"

dry_run=0

# ---- output helpers ----
msg() { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

# ---- action wrapper: run a command, or print it under --dry-run ----
act() {
    if [ "$dry_run" -eq 1 ]; then
        printf '  [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

# ---- environment: strip the blocks install.sh added, leave the rest alone ----
ensure_profile_clean() {
    if [ ! -f "$PROFILE" ] || ! grep -q '(added by nine)$' "$PROFILE"; then
        info "no nine blocks in $PROFILE"
        return
    fi
    if [ "$dry_run" -eq 1 ]; then
        info "[dry-run] would remove the blocks marked \"(added by nine)\" from $PROFILE"
        return
    fi
    tmp=$(mktemp)
    # every block install.sh writes is exactly two lines: a comment
    # ending in "(added by nine)" and the export right after it
    awk '
        /\(added by nine\)$/ { skip = 1; next }
        skip > 0 { skip = 0; next }
        { print }
    ' "$PROFILE" >"$tmp"
    mv "$tmp" "$PROFILE"
    info "removed nine blocks from $PROFILE"
}

usage() {
    cat <<EOF
uninstall -- remove everything nine installed.

usage: ./uninstall.sh [--dry-run] [-h|--help]

  --dry-run   show what would happen, change nothing
  -h, --help  show this help
EOF
}

main() {
    if [ "$dry_run" -eq 1 ]; then
        msg "== dry-run: no changes will be made =="
    fi
    msg "uninstall -- removing everything nine installed"
    msg ""
    msg "1. plan9port"
    act rm -rf "$PLAN9_DIR"
    msg "2. symlinks and launcher"
    for b in $LINKS; do
        act rm -f "$BIN_DIR/$b"
    done
    msg "3. desktop entry"
    act rm -f "$DESKTOP_DIR/acme.desktop"
    msg "4. environment"
    ensure_profile_clean
    msg ""
    msg "done. this repo clone, uninstall.sh included, is untouched --"
    msg "remove it yourself if you're done with it."
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            dry_run=1
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1 (try --help)"
            ;;
    esac
    shift
done

main
