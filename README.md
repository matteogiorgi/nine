# NINE as in *Plan 9 from User Space*

*A no-frills guide to installing Acme (plan9port) on Debian — and living in it with everything default.*

Third companion to [`ULPE`](https://github.com/matteogiorgi/ulpe) (a UNIX-like terminal environment) and [`COBE`](https://github.com/matteogiorgi/cobe) (a VS Code environment): **NINE is the just-Acme, zero-config path.** No dotfiles, no theming, no keybindings to memorize — in Acme you build your commands in the text itself. This repo is *not* a configuration; it is the **knowledge** of how to install Acme correctly on Debian, with the sharp edges annotated. It automates nothing that it does not first explain.




## Why this exists (and why there is no `apt install`)

- Acme is part of [**plan9port**](https://9fans.github.io/plan9port/) (Plan 9 from User Space). There is **no** `plan9port` package in Debian's repositories, so the canonical route — the one 9fans themselves document — is to **build from source**. It is short and clean, just not a one-liner.
- Acme is deliberately **config-free**: no rc files, no themes, no plugin system. You change font and tabstop with flags, and that is the extent of it. That is exactly why it fits an "everything default" project: there is nothing to configure.
- The only real work, then, is *installing* it right: dependencies, build, environment. Once that is done, you are living on pure defaults.




## Before you start: two hard prerequisites

1. **A graphical display (X11).** Acme is a GUI program, not a terminal editor. Locally that is your X session; over the network it is `ssh -X your-debian-host`. If what you actually want is a *terminal-only* structural editor from the same family, use `sam` in command mode (`9 sam -d`) instead — it shares the philosophy and needs no display.

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


### 4. Expose the binaries — symlink, do not pollute `PATH`

plan9port ships ~150 binaries in `$PLAN9/bin`, and many of them **shadow GNU tools**: `cat`, `sed`, `grep`, `ls`, `awk`, `tr`, `sort`, and more. Appending `$PLAN9/bin` to `PATH` would drag every one of those names into your namespace and tab-completion, with a standing risk that a script picks up the Plan 9 version. Instead, symlink only the handful you invoke directly:

```sh
mkdir -p "$HOME/.local/bin"
for b in 9 acme sam 9term win fontsrv plumb; do
    ln -sf "$PLAN9/bin/$b" "$HOME/.local/bin/$b"
done
```

On Debian, `~/.profile` already prepends `~/.local/bin` to `PATH` when that directory exists, so there is usually nothing else to do. Verify with `echo $PATH`; if `~/.local/bin` is missing from it, add it yourself:

```sh
# in ~/.profile
export PATH="$HOME/.local/bin:$PATH"
```

Everything you did *not* symlink is still reachable through the `9` wrapper, without touching `PATH`:

```sh
9 grep ...   # the Plan 9 grep, explicitly
9 mk         # Plan 9 make
9 sed ...    # the Plan 9 sed
```

This keeps your GNU/POSIX tools — and any dispatcher scripts that rely on them — completely untouched.


### 5. Reload and verify

```sh
. ~/.profile
command -v acme        # -> ~/.local/bin/acme
echo "$PLAN9"          # -> /home/you/plan9
```




## First launch

```sh
acme &
```

**Test the middle button immediately.** Type the word `Newcol` anywhere in the text, select it, and click it with the **middle** button. A new column should open. If nothing happens, you do not have three working buttons — fix that before going any further, because it is the whole interface.




## Fonts (optional — tune later, not first)

Acme's default bitmap Lucida is tiny on dense screens. To use nicer or larger fonts, run `fontsrv` (which exposes host fonts to Acme through a 9P namespace) and point Acme at a font under its tree:

```sh
fontsrv &
acme -f /mnt/font/GoMono/13a/font &
```

The exact mount path depends on your namespace setup; see `man fontsrv`. For the very first run, launch plain `acme &` and see how it feels — sitting on the raw defaults is the entire point of this project. Reach for `fontsrv` only if the default is unusable.




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
      "$HOME"/.local/bin/plumb
# then remove the two blocks marked "(added by nine)" from ~/.profile
```




## The one thing to read

Acme makes little sense until you have read Rob Pike's short paper *"Acme: A User Interface for Programmers."* It is ten enjoyable pages, and after them every click lands where you expect. That paper is the real manual — this repo just gets you to the door.
