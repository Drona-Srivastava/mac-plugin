# Mac Desktop for Omarchy

A **macOS-inspired dark appearance** for Omarchy: a translucent menu bar, compact dark dock with colourful app tiles, and optional matching desktop/app colours. Omarchy's logo, shortcuts and Hyprland window styling remain yours.

**0.1.1 is a base-appearance preview.** Music, weather, calendar, Control Center and desktop widgets are deliberately deferred. This is not macOS, a macOS emulator, or an Apple Music client.

## Requirements

Initial compatibility target: **Omarchy 4.0.4**, **Quickshell 0.3.1**, **Hyprland 0.56.2**, and Python 3.11+. These are the development versions, not a promise of compatibility with every later release. The plugin uses a scoped, licensed clone of Omarchy 4.0.4's bar renderer and its installed plugin APIs. Older Waybar-based Omarchy installations are not supported.

No extra font, icon theme, privileged installer, or package download is required. Fonts and app icons come from your installed system.

## Install

Before installing, record your current bar and back up its layout:

```bash
cp ~/.config/omarchy/shell.json ~/.config/omarchy/shell.json.before-mac
omarchy plugin add https://github.com/Drona-Srivastava/mac-plugin.git --enable
```

Omarchy prompts before running a third-party plugin. Plugins are **unsandboxed code in your desktop session**; review the repository first. Non-interactive automation may use Omarchy's `--yes` option.

The installer activates the bar/dock, not external application theming. The appearance panel opens once on first enable. Reopen it with the small sliders button in the top bar or:

```bash
omarchy-shell drona-mac settings
```

The **Apply appearance** action is explicitly confirmed and reversible. There is no automatic installation hook or background package installer.

## What this preview changes

- A translucent dark top bar with sans-serif labels and the original Omarchy logo.
- Optional Mac-style arrangement: active app on the left, clock at the far right.
- Existing configured widgets retained, not replaced by dummy controls.
- A floating dock for pinned/running apps, colourful rounded icon tiles, gentle hover scaling, application focus/launch and contextual actions.
- Dock size/autohide, reduced transparency and reduced motion settings.
- Optional dark GTK/Nautilus and stock-shell colour integration using the appearance helper.
- Original wallpapers for manual selection: **Prism Night** (violet/cobalt/teal fans inspired by the supplied reference) and **Graphite Tide** (quieter dark waves).

The plugin inherits a **scoped local clone** of the Omarchy bar, with upstream licensing retained in `renderer/`. Packaged files are never patched. Existing menus, widget rendering and popup routing remain in use. On Omarchy 4.0.4 a blank configured logo after a hot switch triggers a bounded widget-catalog rescan; this resets stale component contexts without changing configuration or restarting the lock client. Settings are persisted in the namespaced `bar.macDesktop` field in `~/.config/omarchy/shell.json`; the saved widget layout is not rewritten to achieve the Mac arrangement.

No global shortcuts, Hyprland rules, corners, gaps, borders, blur, shadow or opacity settings are changed. No Apple traffic-light window controls are added. Nautilus remains Nautilus; no unsupported libadwaita CSS patching is performed.

### Settings

Use the appearance panel for normal changes. The following keys are stored under `bar.macDesktop`:

| Key | Default | Meaning |
|---|---|---|
| `dockEnabled` | `true` | Show the app dock |
| `dockAutoHide` | `true` | Reveal the dock at the screen edge |
| `dockSize` | `48` | Icon size, clamped to 32–72 logical pixels |
| `dockPins` | `[]` | Up to 40 desktop-entry IDs; first run uses detected default apps |
| `dockPinsInitialized` | `false` | Set after editing pins, so unpinning everything stays empty |
| `dockMonitor` | `""` | Empty for all monitors, otherwise an output name |
| `macLayout` | `true` | Active-app label and right-aligned clock; saved layout is retained |
| `reduceMotion` | `false` | Reduce plugin-owned animations |
| `reduceTransparency` | `false` | Use solid plugin surfaces |

A one-time `onboarded` flag records that the welcome panel was shown. Preferences are retained when switching bars, so they are available on re-enable.

## Appearance helper

Run the helper from the installed plugin:

```bash
PLUGIN="$HOME/.config/omarchy/plugins/drona.mac"
python3 "$PLUGIN/scripts/appearance" --help
python3 "$PLUGIN/scripts/appearance" status
python3 "$PLUGIN/scripts/appearance" apply       # preview only
python3 "$PLUGIN/scripts/appearance" apply --yes
python3 "$PLUGIN/scripts/appearance" restore    # preview only
python3 "$PLUGIN/scripts/appearance" restore --yes
```

The helper maintains a restore journal outside the plugin checkout. It never runs a full `omarchy theme set`: that could change your window-border colours. It does not install packages or change authentication, toolkit CSS or keybindings. See [the detailed recovery contract](appearance/SAFETY.md), including the conservative whole-file shell-palette conflict check.

### Optional wallpaper

The wallpaper is **not** applied or restored by the colour helper. Record your old image path first:

```bash
readlink -f ~/.local/state/omarchy/current/background
omarchy theme bg set "$HOME/.config/omarchy/plugins/drona.mac/appearance/wallpapers/prism-night.png"
```

Keep the previous path to restore it with `omarchy theme bg set /path/to/previous-image`. Select another image before removing the plugin so the background link is not left pointing into a deleted checkout.

Restoration is conflict-aware: if you changed a value after the plugin applied it, the helper reports the conflict instead of overwriting your newer preference. Backups are not a substitute for reviewing the proposed changes.

## Recovery and removal

Switch to the stock bar at any time:

```bash
omarchy plugin enable omarchy.bar
```

**Omarchy 4.0.4 hot-switch caveat:** a bar swap can leave stale panel routing. The appearance panel's return button uses `scripts/return-to-stock`, which switches to the stock bar and runs the supported, lock-aware `omarchy restart shell`. For command-line recovery, run that helper or run `omarchy restart shell` after the switch while unlocked.

This unloads the Mac bar/dock, but **does not undo external application colours**. Before removal, restore those separately:

```bash
python3 ~/.config/omarchy/plugins/drona.mac/scripts/appearance restore --yes
bash ~/.config/omarchy/plugins/drona.mac/scripts/return-to-stock
omarchy plugin remove drona.mac
```

If you previously used another replacement bar, enable its ID instead of `omarchy.bar`. The installer changes `bar.id` before a plugin can record it; keep your pre-install backup.

If shell IPC is unavailable, back up `~/.config/omarchy/shell.json`, change only `bar.id` to `omarchy.bar`, and restart the shell **while unlocked**. Do not reset the entire Omarchy configuration just to remove this plugin. See [recovery details](docs/RECOVERY.md).

## Update

Switch to the stock bar before updating, then re-enable:

```bash
bash ~/.config/omarchy/plugins/drona.mac/scripts/return-to-stock
omarchy plugin update drona.mac
omarchy plugin enable drona.mac
```

Omarchy's updater follows upstream HEAD, not the version in `manifest.json`; `main` is kept release-ready. Record the previous git commit if you want an exact code rollback. Never keep runtime state or private data in the checkout, and save local source modifications before removing it.

## Validation and development

```bash
omarchy plugin validate .
node tests/test_preferences.cjs
node --test tests/dock-helpers.test.mjs
python3 -m unittest discover -s tests -v
scripts/smoke-test
```

Use Qt **6** tools (`/usr/lib/qt6/bin/qmlformat` and `/usr/lib/qt6/bin/qmllint` on Arch); unqualified commands may point to Qt 5. `scripts/smoke-test` connects to an existing Wayland session with an isolated QML config and exits. All plugin windows stay hidden; it does not replace the running shell. It verifies component creation and local-renderer compilation, not live pointer behavior.

Read-only protected-setting verification:

```bash
scripts/check-invariants snapshot /tmp/mac-before.json
# Enable the plugin / apply appearance.
scripts/check-invariants compare /tmp/mac-before.json
```

The snapshot includes private local configuration hashes and keybinding commands; do not commit or publish it.

## Known boundaries

- Translucency is not native Apple's Liquid Glass refraction. Existing global blur settings are untouched. Use Reduce transparency for a solid high-contrast bar.
- Application styling is limited to supported toolkit preferences. There is no exact Finder replacement.
- A replacement bar has restricted service access. Third-party widgets requiring direct service objects may need upstream support; revert to the stock bar if one does not work.
- Stock panels retain their structure and window-corner rules; the optional palette coordinates their colours only.
- The Mac bar always renders at the top. Your prior bar placement/layout returns with the stock bar.
- No universal Linux global menu, native macOS minimization, AirDrop, Continuity or Apple account integration is claimed.
- Hardware, multi-monitor and accessibility support require testing on your system; see [compatibility notes](docs/COMPATIBILITY.md).

## Design and licensing

Inspired by the dark appearance of macOS 27 Golden Gate and the user's supplied transparent-bar/colourful-dock reference; no Apple logos, fonts, icon packs or wallpapers are bundled. This project is independent of Apple and Omarchy.

[MIT license](LICENSE) · [Third-party notices](THIRD_PARTY_NOTICES.md) · [Long-term plan](PLAN.md)
