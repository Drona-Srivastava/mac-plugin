# Base appearance helper and asset contract

`drona.mac` does not apply external appearance settings automatically. From the
plugin checkout, using Python 3.9 or newer:

```sh
./scripts/appearance status                 # JSON; no writes
./scripts/appearance apply                  # exact available-change preview
./scripts/appearance apply --yes            # consent to available adapters
./scripts/appearance apply --yes --dry-run  # still a preview, no writes
./scripts/appearance restore                # restore/conflict preview
./scripts/appearance restore --yes          # restore only unchanged owned state
```

All results are JSON. Exit codes: `0` success/preview/already applied, `1`
failure or no available adapters, `2` recovery required or restore conflicts.
Flags `--no-gnome` and `--no-shell-palette` restrict **apply/preview**; restore
always considers all entries in its existing journal. Restore before changing
adapter selection on an active transaction. A repeated apply never refreshes
original backups or overwrites a later user edit.

## What can change

- Two writable `org.gnome.desktop.interface` preferences, if both `gsettings`
  and `dconf` are already available: `color-scheme='prefer-dark'` and
  `gtk-theme='Adwaita-dark'`. The helper preserves both effective values and the
  presence/absence of explicit dconf values. An inherited original is restored
  with `gsettings reset`, not pinned to an old default. Other GSettings backends
  are rejected. These are supported application hints, **not** a promise of
  uniform third-party application appearance. No GTK theme is installed and no
  theme-package availability claim is made.
- Colour-only `[bar]`, `[popups]`, `[tooltip]`, `[notifications]` and `[menu]`
  overrides in user `shell.toml`. `appearance/shell-palette.toml` contains the
  exact palette. Opaque charcoal/graphite surfaces, pale text and blue selection
  colours work without enabling blur. No geometry, typography, shared-control,
  polkit, lock, logo or shell-layout keys are changed. Existing unrelated lines,
  keys and inline comments survive application.

The shell adapter checks the installed read-only
`/usr/share/omarchy/shell/Commons/Color.qml` user-override interface and palette
keys, inspected against Omarchy 4.0.4. This implementation hardcodes
`HOME/.config/omarchy/shell.toml`. With a different `XDG_CONFIG_HOME`, the helper
**skips** the shell adapter rather than writing either an ineffective override
or a different configuration location. Unsupported syntax, duplicate sections or
keys, symlinks, hardlinks and oversized input are rejected rather than rewritten.
The accepted syntax is the shell's simple line-oriented subset, not all TOML.
Missing/unsupported adapters are listed in `skipped`; supported adapters can
still proceed with consent.

No full theme switch, compositor command, Hyprland file edit/reload, binding,
logo replacement, shell.json modification, icon/font/package installation,
toolkit CSS patch, terminal configuration, network request, privilege escalation
or authentication change is performed. There is no runtime dependency beyond
Python's standard library and the already-installed adapter commands. No
before/after **live** compositor validation is claimed: the helper never uses a
compositor-writing interface. Tests enforce its external command allowlist.

## Journal and recovery

There is one private, versioned write-ahead journal at:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/plugins/drona.mac/appearance-v1.json
```

Relative/empty XDG variables fall back to their specification defaults.
Configuration and state destinations inside the source checkout or packaged
system directories are rejected. The state directory is private (`0700`) and
new journal files are `0600`. Original and applied shell snapshots are bounded
to 128 KiB each; the entire journal is bounded to 512 KiB, with at most three
entries and no unbounded backup history. Journal/file updates use same-directory
atomic rename and file/directory `fsync`; a persistent advisory lock serializes
this helper's writes. Status and preview do not even create a lock directory.

A caught apply failure (including SIGINT/SIGTERM) attempts conflict-aware rollback
immediately. After a hard kill or failed rollback, run `restore --yes` from the
same checkout, **with the same HOME/XDG and dconf profile**, to reconcile the
write-ahead journal. A changed HOME, XDG configuration root or DCONF_PROFILE is
rejected before restoring anything. Unperformed operations and already-restored entries are
recognized. A corrupt/unknown journal is preserved and rejected, not guessed at.
A hard kill during atomic file preparation can leave an inert `.drona-mac-*`
temporary file next to the destination; no such file is ever loaded as config.

Restore is conservative:

- GNOME keys are restored independently only if their current explicit/effective
  value still matches the helper's write (or is already original).
- Shell restoration is **whole-file compare-and-swap**, including permissions.
  Any later edit, even an unrelated one, leaves the entire file untouched and
  retains its recovery entry. Untouched files are restored byte-for-byte; a file
  absent before apply is removed only if still exactly owned.
- Successful entries are checkpointed and removed; conflicts keep their backups
  for a later retry. Complete restore removes the journal, not arbitrary files
  or its lock directory. The helper never offers a force-overwrite option.
- Review the local journal's base64 shell snapshots to resolve a conflict
  manually. After manually restoring the original file/value, retry restore to
  finish. Do not delete recovery data until satisfied with the result.

The lock does not serialize external editors or settings daemons. Avoid editing
these settings during apply/restore; equality is checked immediately before and
after each write, but no user-space helper can provide a cross-process atomic
compare-and-swap for GSettings. A later user choice identical to the helper's
value is indistinguishable from an unchanged owned value. This limitation is
reported in every JSON response.

## Original wallpaper — asset only

`wallpapers/graphite-tide.png` is a 2560×1600 abstract dark-blue/graphite wallpaper.
It is generated entirely from original mathematical curves: no Apple artwork,
logos, downloaded source images or fonts. The image and its generator are
available under **CC0-1.0** (public-domain dedication;
<https://creativecommons.org/publicdomain/zero/1.0/>). The generator needs no
Pillow or other third-party packages:

```sh
python3 appearance/generate_wallpaper.py
# Optional explicit output/dimensions:
python3 appearance/generate_wallpaper.py --width 3840 --height 2160 --output /path/to/graphite-tide.png
```

**The helper does not apply or journal wallpapers.** The inspected installed
`omarchy theme bg set` replaces a hardcoded
`$HOME/.local/state/omarchy/current/background` symlink before invoking shell IPC;
its interface cannot reliably recover an absent prior background or honor an
alternate XDG state home. Rather than promise reversible behavior around that
interface, v0.1 ships the wallpaper for preview/manual selection only. Any manual
wallpaper choice is outside this helper's restore contract.

## Isolated verification

```sh
python3 -m unittest discover -s tests -p 'test_appearance.py' -v
```

Tests use temporary homes and mock every preference command. CLI smoke tests use
stub commands and a temporary HOME/state directory, never the live dconf session.
No test applies an appearance change to the actual desktop.
