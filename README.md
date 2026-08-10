# NINE as in *Plan 9 from User Space*

*A no-frills guide to installing [Acme](http://acme.cat-v.org/) (plan9port) on Debian — and living in it with everything default.*

Third companion to [`ULPE`](https://github.com/matteogiorgi/ulpe) (a UNIX-like terminal environment) and [`COBE`](https://github.com/matteogiorgi/cobe) (a VS Code environment): **NINE is the just-Acme, zero-config path.** No dotfiles, no theming, no keybindings to memorize — in Acme you build your commands in the text itself. This repo is *not* a configuration; it is the **knowledge** of how to install Acme correctly on Debian, with the sharp edges annotated. It automates nothing that it does not first explain.




## Why this exists (and why there is no `apt install`)

- Acme is part of [**plan9port**](https://9fans.github.io/plan9port/) (Plan 9 from User Space). There is **no** `plan9port` package in Debian's repositories, so the canonical route — the one 9fans themselves document — is to **build from source**. It is short and clean, just not a one-liner.
- Acme is deliberately **config-free**: no rc files, no themes, no plugin system. You change font and tabstop with flags, and that is the extent of it. That is exactly why it fits an "everything default" project: there is nothing to configure.
- The only real work, then, is *installing* it right: dependencies, build, environment. Once that is done, you are living on pure defaults.




## Before you start: two hard prerequisites

1. **A graphical display (X11).** Acme is a GUI program, not a terminal editor. Locally that is your X session; over the network it is `ssh -X your-debian-host`. If what you actually want is a *terminal-only* structural editor from the same family, use `sam` in command mode (`sam -d`) instead — it shares the philosophy and needs no display.

2. **A real three-button mouse.** Acme's entire model is mouse chording:
   - **left** selects,
   - **middle** executes the text under it as a command,
   - **right** searches/opens the text under it as a file or pattern,
   - **chords** (hold one button, click another) do cut and paste.

   On a trackpad without three physical buttons this collapses. If you SSH in from a tablet, plug in a real mouse *before* judging Acme — otherwise you are judging its worst version.




## Install (manual — the source of truth)

This is everything the installer script does, done by hand. If you only ever read this section, you are self-sufficient.


### 1. Build dependencies (from apt)

```sh
sudo apt install gcc git libx11-dev libxt-dev libxext-dev libfontconfig1-dev
```


### 2. Clone and build

Convention is `$HOME/plan9`. The `./INSTALL` script (no flags) compiles everything in place:

```sh
git clone https://github.com/9fans/plan9port "$HOME/plan9"
cd "$HOME/plan9"
./INSTALL
```

The first build takes a few minutes. If it stops, complaining about a missing header, install the named `-dev` package and re-run `./INSTALL` — it resumes rather than restarting from scratch.


### 3. Environment (`$PLAN9` is required)

Acme locates its resources (fonts, lib, support files) through `$PLAN9`, so this export is required **no matter how you expose the binaries**:

```sh
# in ~/.profile
export PLAN9="$HOME/plan9"
```

**Why `~/.profile` and not `~/.bashrc`:** this is session-level environment, not an interactive-shell nicety. Placed in `.profile`, it is set once at login and inherited by X programs (so Acme launched over `ssh -X` sees it) and by the tmux server (so every pane sees it). Reserve `.bashrc` for the prompt, aliases, and functions.

That assumes something sources `.profile` at login in the first place — true for a standard X11 session, less certain in things like a ChromeOS Linux container, where a terminal can open a non-login shell that never reads it. `nine` itself doesn't take that for granted (see Fonts).


### 4. Expose the binaries — symlink, do not pollute `PATH`

plan9port ships ~150 binaries in `$PLAN9/bin`, and many of them **shadow GNU tools**: `cat`, `sed`, `grep`, `ls`, `awk`, `tr`, `sort`, and more. Appending `$PLAN9/bin` to `PATH` would drag every one of those names into your namespace and tab-completion, with a standing risk that a script picks up the Plan 9 version. Instead, symlink only a curated handful — the ones you type, plus a few internal helpers other plan9port programs need at runtime:

```sh
mkdir -p "$HOME/.local/bin"
for b in 9 acme sam 9term win fontsrv plumb 9pserve devdraw 9pfuse samterm; do
    ln -sf "$PLAN9/bin/$b" "$HOME/.local/bin/$b"
done
```

Four of those you never type yourself — they are internal helpers other plan9port programs exec by bare name, which resolves through `$PATH`, and since this repo deliberately keeps `$PLAN9/bin` off `PATH`, they have to be symlinked here too, purely so that search succeeds:

- `9pserve` and `devdraw` are needed for Acme to start at all. Skip either and it fails at startup — without `devdraw`: `exec devdraw: No such file or directory` followed by `can't open display: muxrpc: unexpected eof`; without `9pserve`: it draws its window, then `exec 9pserve: No such file or directory` followed by `can't post service: 9pserve failed`.
- `9pfuse` is only needed for the optional host-font route in the Fonts section below — it mounts `fontsrv`'s output through FUSE. Baseline Acme never touches it.
- `samterm` is needed only for `sam`'s GUI mode — running bare `sam` execs it the same way Acme execs `devdraw`. Skip it and you get `can't exec samterm: No such file or directory`. Command-mode `sam -d` (the way this repo actually recommends using it, see "Before you start") never touches it.

On Debian, `~/.profile` already prepends `~/.local/bin` to `PATH` when that directory exists, so there is usually nothing else to do. Verify with `echo $PATH`; if `~/.local/bin` is missing from it, add it yourself:

```sh
# in ~/.profile
export PATH="$HOME/.local/bin:$PATH"
```

Everything you did *not* symlink is still reachable through the `9` wrapper, without touching `PATH`:

```sh
9 grep ...    # the Plan 9 grep, explicitly
9 mk          # Plan 9 make
9 sed ...     # the Plan 9 sed
```

This keeps your GNU/POSIX tools — and any dispatcher scripts that rely on them — completely untouched.


### 5. Reload and verify

```sh
. ~/.profile
command -v acme    # -> ~/.local/bin/acme
echo "$PLAN9"      # -> /home/you/plan9
```




## First launch

```sh
acme &
```

**Test the middle button immediately.** Type the word `Newcol` anywhere in the text, select it, and click it with the **middle** button. A new column should open. If nothing happens, you do not have three working buttons — fix that before going any further, because it is the whole interface.




## Fonts (optional — tune later, not first)

Acme's default bitmap Lucida is tiny on dense screens, and proportional besides. Two ways to change it, in increasing order of effort. For the very first run, though, launch plain `acme &` and see how it feels — sitting on the raw defaults is the entire point of this project. Reach for either of the below only if the default is unusable.

**Built-in, no extra moving parts.** plan9port ships its own bitmap fonts directly under `$PLAN9/font/` — no `fontsrv`, no mounting, nothing to go wrong. Same monospace family, two sizes:

```sh
acme -f "$PLAN9/font/pelm/unicode.9.font" &    # monospace, readable
acme -f "$PLAN9/font/pelm/unicode.8.font" &    # monospace, tighter
```

`pelm` ships the same family at 8, 9, 10, 12, and 16. Browse `$PLAN9/font/` for other styles entirely — `lucsans`, `fixed`, `misc`, `times`, `palatino`, and several CJK sets — but most are either proportional or the same blocky look as classic X11 terminal fonts.

**A modern host font, through `fontsrv`.** To use a TrueType/OpenType font already installed on your system instead of a built-in one, `fontsrv` bridges it into a 9P namespace Acme can read from. Finding the font's name first helps: `fc-list :spacing=mono family` lists what you have (Cascadia, Go Mono, DejaVu Sans Mono, and the like) — but `fc-list` comes from the `fontconfig` package specifically, not the `libfontconfig1-dev` headers from step 1, so it isn't guaranteed to be there; `command -v fc-list` to check, `sudo apt install fontconfig` if not. Three things about `fontsrv` itself that aren't obvious from `-h`:

- `fontsrv` alone posts a service but mounts nothing; you need `-m <mtpt>`.
- `/mnt` is root-owned on Debian — not writable by you. Use a directory under `$HOME`.
- The mount goes through `9pfuse` (symlinked in step 4 for exactly this), which needs FUSE working on your system — usually already the case; `command -v fusermount` to check, `sudo apt install fuse3` if not.

```sh
mkdir -p "$HOME/lib/font"
fontsrv -m "$HOME/lib/font" &
ls "$HOME/lib/font"
acme -f "$HOME/lib/font/CascadiaMono-Roman/10a/font" &
```

Check that `ls` first — names come out styled, not just by family: that's why the example above says `CascadiaMono-Roman`, not `CascadiaMono`. If it isn't there at all, Cascadia itself is missing — `sudo apt install fonts-cascadia-code`; any other monospace TrueType font works the same way.

**Making a font choice permanent.** Acme itself never remembers one — no config file, by design. `nine` instead writes a small launcher — also named `nine`, distinct from the `9` wrapper from step 4 despite the similar name — to `~/.local/bin/` (not an alias, so it works no matter what invokes it, not just interactive shells that source `~/.bashrc`):

```sh
#!/bin/sh
# nine -- launch Acme, preferring a modern host font via fontsrv,
# falling back to a built-in monospace; hands files to an already-running
# instance via plumb instead of failing to start a second one (added by nine)
set -eu

# $PLAN9 is only exported from ~/.profile, which login shells read and
# plenty of terminals/desktop launchers don't count as -- acme itself
# tolerates that and falls back to a built-in font, but this script
# dereferences $PLAN9 right away, so default it rather than join acme
# in assuming a login shell got there first
export PLAN9="${PLAN9:-$HOME/plan9}"

NS=$("$PLAN9/bin/namespace")

# a dead acme can leave its socket file behind without unlinking it;
# a mere -e check would treat that stale file as "still running" and
# never get past this block, so actually try to reach it -- a stale
# socket doesn't always refuse the connection outright, it can hang
# instead, so this needs a hard timeout rather than trusting 9p to
# fail fast
acme_running() {
    [ -e "$NS/acme" ] && timeout 2 "$PLAN9/bin/9p" read acme/index >/dev/null 2>&1
}

if acme_running; then
    if [ $# -eq 0 ]; then
        echo "nine: acme is already running" >&2
        exit 0
    fi

    send() {
        case "$1" in
            /*) abs="$1" ;;
            *) abs="$PWD/$1" ;;
        esac
        plumb -s B -d edit "$abs"
    }

    if [ -e "$NS/plumb" ]; then
        for f in "$@"; do
            send "$f"
        done
    else
        "$PLAN9/bin/plumber" &
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            [ -e "$NS/plumb" ] && break
            sleep 0.3
        done
        # acme reconnects to a freshly (re)started plumber on its own
        # fixed 2-second retry loop; sending before that lands finds
        # no listener on "edit", so plumber's default rule launches a
        # *second* acme instead -- give the loop a full cycle first
        sleep 2.5
        for f in "$@"; do
            send "$f"
        done
    fi
    exit 0
fi

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
```

Before any of that, it defaults `$PLAN9` to `$HOME/plan9` if it isn't already set. Step 3 explains why the export lives in `~/.profile` rather than `~/.bashrc` — but `~/.profile` is a *login*-shell file, and not every terminal or desktop launcher counts as one; Acme itself tolerates a missing `$PLAN9` and quietly falls back to its own built-in font, but `nine` dereferences `$PLAN9` immediately (for `namespace`, next), so without this default it would fail outright with `PLAN9: parameter not set` instead of degrading gracefully like Acme does.

On every run it first checks whether Acme is already running, via `$NS/acme` (`$NS` from `namespace`, a plan9port command that isn't itself symlinked — `nine` calls it by its full `$PLAN9/bin` path). Acme posts itself as a single named service, so a second instance always fails to start with `acme: can't post service` — a second `acme` was never the way to open more things anyway. That check is more than a file test: closing Acme's window can leave the socket file behind without anything actually listening on it, and a stale socket doesn't always refuse a connection outright — it can just hang. So `nine` tries a real, `timeout`-bounded round trip (`9p read acme/index`, again by full path — same treatment as `namespace`) rather than trusting that a dead socket fails fast; treating a leftover file as "running" would otherwise get you stuck here forever, unable to open Acme at all. If it's genuinely running and you passed no files, `nine` just says so and exits. If you passed files, it hands them to the running instance instead of trying (and failing) to start a new one, via `plumb -s B -d edit` — the same mechanism plan9port's own `B` command uses, built entirely on `plumb` from step 4.

The one thing that needs a moment: `plumb`'s own daemon, `plumber` (also not symlinked — same full-`$PLAN9/bin`-path treatment as `namespace`), isn't started by anything else in this repo, so `nine` starts it lazily, the first time a running Acme needs to receive a file. Acme reconnects to a freshly-started `plumber` on its own fixed 2-second retry loop — the source (`cmd/acme/look.c`) says so directly: *"Loop so that if plumber is restarted, acme need not be."* Send before that reconnect lands, and `plumber`'s default rule launches a **second** Acme instead of delivering to the first, which is the exact failure this is meant to avoid — so `nine` waits out a full cycle before sending. That wait (a few seconds) only happens once per session, the first time you hand a file to an already-running Acme; `plumber` then keeps running, and every later handoff is instant.

If Acme *isn't* already running, `nine` checks whether `$HOME/lib/font` is already mounted and, if not, mounts `fontsrv` there (waiting for the mount rather than racing `acme` against it — if it never mounts, that's FUSE not working, see above). Then it tries, in order:

1. `CascadiaMono-Roman` specifically — needs the `fonts-cascadia-code` package.
2. Failing that, whatever `fc-match` says your system's generic `monospace` resolves to, if that lookup is available (needs `fontconfig`, see above) and `fontsrv` exposes a font under that exact name.
3. Failing that too, the built-in `pelm/unicode.8.font`, which needs nothing beyond plan9port itself and therefore never fails.

Whenever it lands on anything but its first choice, it says so on stderr — and where relevant, exactly what to `apt install`, batched into one line the same way step 1 reports missing build dependencies. On later runs, since the mount is already there, it skips straight to these checks. Launch it in place of `acme`:

```sh
nine &
```

Edit `~/.local/bin/nine` to change the font, the size, or the fallback — `nine` writes the file once and never overwrites an existing one, so your edits stick.

**A menu entry, too.** `nine` also writes `~/.local/share/applications/acme.desktop`, pointed at `nine` itself — so Acme shows up in your desktop environment's application menu and in "Open With" dialogs, launched with the same font logic, not the raw default; and since `nine` handles an already-running Acme (above), opening a file this way while Acme is already open hands it to that instance instead of failing. Desktop launchers are exactly the kind of context that can skip `~/.profile`, which is also why `nine` defaults `$PLAN9` itself rather than trusting it's already set (above) — otherwise this entry would fail every time. (No `MimeType=` is set, so it won't become the double-click default for any file type — add one yourself if you want that.)

```
[Desktop Entry]
Type=Application
Name=Acme
Comment=Plan 9 text editor (plan9port)
Exec=/home/you/.local/bin/nine %F
Terminal=false
Categories=Utility;TextEditor;
```

Note the absolute path in `Exec=`: unlike `~/.profile`, `~/.bashrc`, or `nine` itself, `.desktop` files don't expand `$HOME` or any other variable — `nine` fills it in with the real path when it writes the file. If the entry doesn't show up in your menu right away, reopen the menu or log back in; same idempotent, write-once, never-overwrite rule as everything else `nine` creates.




## Other distributions

Only the dependency names change; steps 2–5 are identical. The `apt` list in step 1 (`gcc git libx11-dev libxt-dev libxext-dev libfontconfig1-dev`) is the example — translate it to your package manager (`dnf`, `pacman`, `zypper`, `apk`, ...): same six things (a C compiler, git, and dev headers for X11, Xt, Xext, fontconfig), under whatever names your distro gives them. Note that the automatic `~/.local/bin` on `PATH` is a Debian default — on other distros, make sure that directory is on your `PATH` yourself.




## Uninstall

`nine` hides nothing, so removal is complete and obvious:

```sh
rm -rf "$HOME/plan9"
rm -f "$HOME"/.local/bin/9 \
      "$HOME"/.local/bin/acme \
      "$HOME"/.local/bin/sam \
      "$HOME"/.local/bin/9term \
      "$HOME"/.local/bin/win \
      "$HOME"/.local/bin/fontsrv \
      "$HOME"/.local/bin/plumb \
      "$HOME"/.local/bin/9pserve \
      "$HOME"/.local/bin/devdraw \
      "$HOME"/.local/bin/9pfuse \
      "$HOME"/.local/bin/samterm \
      "$HOME"/.local/bin/nine
rm -f "$HOME/.local/share/applications/acme.desktop"
# then remove the blocks marked "(added by nine)" from ~/.profile
```




## The one thing to read

Acme makes little sense until you have read Rob Pike's short paper *[Acme: A User Interface for Programmers](https://www.usenix.org/legacy/publications/library/proceedings/sf94/full_papers/pike.pdf)*. It is ten enjoyable pages, and after them every click lands where you expect. That paper is the real manual — this repo just gets you to the door.
