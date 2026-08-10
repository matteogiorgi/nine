#!/bin/sh
# nine -- install Acme (plan9port) on Debian, everything default.
# Executable transcription of README.md. Does nothing the README does not explain.
# POSIX sh; validated with: shfmt -ln posix

set -eu

PLAN9_DIR="$HOME/plan9"
BIN_DIR="$HOME/.local/bin"
PROFILE="$HOME/.profile"
REPO="https://github.com/9fans/plan9port"
DEPS="gcc git libx11-dev libxt-dev libxext-dev libfontconfig1-dev"
LINKS="9 acme sam 9term win fontsrv plumb 9pserve devdraw 9pfuse samterm"

dry_run=0

# ---- output helpers ----
msg() { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
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

# ---- 1. dependencies: detect, print the apt line, never sudo ourselves ----
check_deps() {
    if ! command -v dpkg-query >/dev/null 2>&1; then
        warn "dpkg-query not found -- cannot verify dependencies (non-Debian?)"
        warn "translate to your package manager: $DEPS (apt names, see README)"
        return
    fi
    missing=""
    for pkg in $DEPS; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null |
            grep -q 'install ok installed'; then
            missing="$missing $pkg"
        fi
    done
    if [ -z "$missing" ]; then
        info "all build dependencies present"
        return
    fi
    msg "  missing build dependencies. Install them, then re-run this script:"
    msg ""
    msg "    sudo apt install ${missing# }"
    msg ""
    if [ "$dry_run" -eq 1 ]; then
        warn "continuing dry-run despite missing dependencies"
        return
    fi
    die "dependencies missing"
}

# ---- 2. source: clone only if not already cloned ----
clone_plan9() {
    if [ -d "$PLAN9_DIR/.git" ]; then
        info "$PLAN9_DIR already cloned -- skipping git clone"
        return
    fi
    if [ -e "$PLAN9_DIR" ]; then
        die "$PLAN9_DIR exists but is not a git clone -- move it aside first"
    fi
    act git clone "$REPO" "$PLAN9_DIR"
}

# ---- 3. build: skip if acme is already built ----
build_plan9() {
    if [ -x "$PLAN9_DIR/bin/acme" ]; then
        info "acme already built -- skipping ./INSTALL"
        return
    fi
    if [ "$dry_run" -eq 1 ]; then
        info "[dry-run] would run ./INSTALL in $PLAN9_DIR (a few minutes)"
        return
    fi
    (cd "$PLAN9_DIR" && ./INSTALL)
}

# ---- 4. environment: append the export once, never duplicate ----
ensure_profile() {
    if [ -f "$PROFILE" ] && grep -q 'export PLAN9=' "$PROFILE"; then
        info "PLAN9 export already present in $PROFILE -- leaving it"
        return
    fi
    if [ "$dry_run" -eq 1 ]; then
        info "[dry-run] would append 'export PLAN9=\"\$HOME/plan9\"' to $PROFILE"
        return
    fi
    printf '\n# plan9port (added by nine)\nexport PLAN9="$HOME/plan9"\n' >>"$PROFILE"
    info "added PLAN9 export to $PROFILE"
}

# ---- 5. binaries: symlink a curated set (ln -sf is idempotent) ----
link_bins() {
    act mkdir -p "$BIN_DIR"
    for b in $LINKS; do
        act ln -sf "$PLAN9_DIR/bin/$b" "$BIN_DIR/$b"
    done
}

# ---- 6. PATH: append to $PROFILE once if $BIN_DIR isn't referenced there yet ----
ensure_path() {
    if [ -f "$PROFILE" ] && grep -q '\.local/bin' "$PROFILE"; then
        info "$BIN_DIR already referenced in $PROFILE -- leaving it"
    elif [ "$dry_run" -eq 1 ]; then
        info "[dry-run] would append 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to $PROFILE"
    else
        printf '\n# ~/.local/bin on PATH (added by nine)\nexport PATH="$HOME/.local/bin:$PATH"\n' >>"$PROFILE"
        info "added $BIN_DIR to PATH in $PROFILE"
    fi

    case ":$PATH:" in
        *":$BIN_DIR:"*)
            info "$BIN_DIR is on current PATH"
            ;;
        *)
            warn "$BIN_DIR is not on your current PATH yet"
            warn "log out/in, or run:  . $PROFILE"
            ;;
    esac
}

# ---- font (optional): write the nine launcher to $BIN_DIR once, never overwrite ----
ensure_launcher() {
    if [ -x "$BIN_DIR/nine" ]; then
        info "nine launcher already present in $BIN_DIR -- leaving it"
        return
    fi
    if [ "$dry_run" -eq 1 ]; then
        info "[dry-run] would write $BIN_DIR/nine"
        return
    fi
    cat >"$BIN_DIR/nine" <<'EOF'
#!/bin/sh
# nine -- launch Acme, preferring a modern host font via fontsrv,
# falling back to a built-in monospace (added by nine)
set -eu

FONT_MNT="$HOME/lib/font"
FALLBACK="$PLAN9/font/pelm/unicode.8.font"
SIZE=10a
missing=""

mounted() { mountpoint -q "$FONT_MNT" 2>/dev/null; }

if ! mounted; then
    mkdir -p "$FONT_MNT"
    fontsrv -m "$FONT_MNT" &
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        mounted && break
        sleep 0.3
    done
fi

if mounted; then
    # 1: a specific modern font, if fontsrv exposes it
    if [ -e "$FONT_MNT/CascadiaMono-Roman/$SIZE/font" ]; then
        exec acme -f "$FONT_MNT/CascadiaMono-Roman/$SIZE/font" "$@"
    fi
    missing="$missing fonts-cascadia-code"

    # 2: whatever the system calls "monospace", if we can resolve and find it
    if command -v fc-match >/dev/null 2>&1; then
        family=$(fc-match monospace -f '%{family}' 2>/dev/null | tr -d ' ')
        if [ -n "$family" ] && [ -e "$FONT_MNT/$family/$SIZE/font" ]; then
            echo "nine: CascadiaMono-Roman not found, using $family instead (sudo apt install fonts-cascadia-code for it)" >&2
            exec acme -f "$FONT_MNT/$family/$SIZE/font" "$@"
        fi
    else
        missing="$missing fontconfig"
    fi
else
    missing="$missing fuse3"
fi

# 3: always works
if [ -n "$missing" ]; then
    printf 'nine: using the built-in font. For a nicer one, try:\n\n    sudo apt install %s\n\n' "${missing# }" >&2
fi
exec acme -f "$FALLBACK" "$@"
EOF
    chmod +x "$BIN_DIR/nine"
    info "wrote $BIN_DIR/nine"
}

usage() {
    cat <<EOF
nine -- install Acme (plan9port) on Debian, everything default.

usage: ./install.sh [--dry-run] [-h|--help]

  --dry-run   show what would happen, change nothing
  -h, --help  show this help
EOF
}

main() {
    if [ "$dry_run" -eq 1 ]; then
        msg "== dry-run: no changes will be made =="
    fi
    msg "nine -- installing Acme (plan9port)"
    msg ""
    msg "1. checking build dependencies"
    check_deps
    msg "2. fetching and building source"
    clone_plan9
    build_plan9
    msg "3. environment"
    ensure_profile
    msg "4. binaries and PATH"
    link_bins
    ensure_path
    msg "font (optional, see README)"
    ensure_launcher
    msg ""
    msg "done. start Acme with:  acme &"
    msg "  (or:  nine &  -- same, with a nicer font; see README)"
    msg "first thing inside: type 'Newcol', select it, click it with the MIDDLE button."
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
