# Mac Plugin — implementation and release plan

**Status:** Long-term roadmap. The base-appearance preview is implemented as `v0.1.0`; see `README.md` and `CHANGELOG.md` for shipped scope. Desktop widgets, Music, Control Center and advanced integrations remain future work. This document describes the intended larger product, not a claim that every planned feature is complete.

**Target repository:** <https://github.com/Drona-Srivastava/mac-plugin>

**Proposed plugin ID:** `drona.mac`
**Proposed display name:** Mac-inspired Desktop for Omarchy

## 1. Product goal and protected boundaries

Build one installable Omarchy plugin that gives the desktop a cohesive, macOS-inspired dark appearance: a slim top menu bar, floating dock, coordinated panels, desktop widgets, Music-style now-playing controls, and supported application appearance integration.

This is an Omarchy desktop, not a macOS distribution, emulator, or exact clone. Omarchy identity and Linux application behavior remain visible where appropriate.

### Requirements that must not change

- **Omarchy branding:** retain the Omarchy logo. Do not substitute Apple's logo, boot identity, system name, or branding.
- **Existing keybindings:** preserve every global and application binding. Do not introduce Command-key remapping, intercept existing shortcuts, or silently change what existing launcher shortcuts invoke.
- **Hyprland window styling:** preserve effective border colours/gradients and widths, gaps, corners, shadows, opacity, blur, group styling, window rules, and tiling/floating behavior. Check runtime values, not just whether configuration files were edited.
- Preserve monitor arrangement, scaling, input settings, idle timers, session locking, authentication, and existing applications.

Application content palettes, toolbars, icons and sidebars may be themed within supported interfaces. Do not add macOS traffic-light controls or replace client decorations as part of the default profile.

The request permits animation changes. Start with animations inside plugin-owned surfaces. Any later compositor animation profile must be a separate opt-in change limited to animation settings; it must not modify protected styling or window-management behavior.

### What “full desktop” means

The intended visual coverage is the shell, dock, widgets, wallpaper, supported application palettes, file-manager content, and supported stock menus/panels. Arbitrary third-party applications cannot all be forced into one design safely. Bootloader, display manager, kernel branding, PAM, and the session-lock implementation are not replacement targets.

## 2. Initial development baseline

The original read-only planning inspection found:

| Component | Installed / observed |
|---|---|
| Omarchy | `4.0.4-1` |
| Hyprland | `0.56.2-2` |
| Quickshell | `0.3.1-1` |
| Default graphical file manager | Nautilus, `org.gnome.Nautilus.desktop` |
| Nautilus / libadwaita | `50.3.1-1` / `1:1.9.3-1` |
| Current theme | Dos Moos |
| Active bar selection | Built-in bar; no explicit replacement `bar.id` |
| Existing customization | Custom bar layout with additional third-party widgets |
| Target repository | Public; API reports size zero |
| Working project | Local `mac-plugin` checkout |

Existing widgets must survive the change. Offer a clean Mac-style preset, but do not replace the user's entire `shell.json` with a bundled default.

Important installed references:

- `/usr/share/omarchy/shell/README.md`
- `/usr/share/omarchy/shell/plugins/README.md`
- `/usr/share/omarchy/shell/plugins/bar/README.md`
- `/usr/share/omarchy/bin/omarchy-theme-set`
- `/usr/share/omarchy/bin/omarchy-theme-set-gnome`
- `/usr/share/omarchy/default/themed/hyprland.lua.tpl`

These packaged paths are read-only references, never modification targets.

## 3. macOS design reference

**Reference: macOS 27 Golden Gate, dark appearance.** Apple's security-release list and developer-release list identify **27.0.1**, released **September 28, 2026**, as the latest stable release at research time (September 30, 2026). The major release became publicly available September 14. The separately listed 27.2 beta is not the reference.

Apple's current product page emphasizes refined Liquid Glass, improved readability/contrast, uniform toolbars, edge-to-edge sidebars and an ultraclear-to-tinted appearance control. Adapt those ideas to plugin-owned surfaces; its changed application-window shapes are explicitly excluded by this project's protected-style requirement.

Use the official release's dark-mode design as a reference, not proprietary implementation or redistributed assets. Record this design-reference version and the source/version of each reference screenshot so later macOS releases do not silently change the target. Apple's product pages and individual user guides do not necessarily update together, and they are not a pixel-perfect specification.

### Proposed visual direction

- Charcoal surfaces, soft white text, restrained blue accent, subtle separators and layered translucent panels.
- Original or permissively licensed wallpapers, icons, and fonts. Use an open font such as Inter with appropriate script fallbacks, not bundled San Francisco or SF Symbols.
- Stronger glass treatment on the dock and quick controls; flatter, more readable surfaces behind dense settings and file lists.
- Rounded plugin panels and widget cards without changing application-window corners.
- Smooth short fade/slide/scale transitions; no perpetual decorative animation when idle.
- Reduced-motion, reduced-transparency, high-contrast, and battery-friendly presets.
- Transparency must degrade gracefully when compositor blur is disabled. Do not turn global blur on to achieve the reference appearance.
- Treat true refractive glass effects as an optional performance-tested enhancement, not a release requirement.

Exact colour, typography, corner, spacing and animation tokens should be defined in one design-system module and tuned against contrast and scaling tests. Initial values are project design choices, not claimed Apple specifications.

## 4. Feature scope

| Surface | Planned experience | Constraints / fallback |
|---|---|---|
| Top bar | Omarchy logo/menu at left, active application label, compact workspace access, tray/status controls and date/time at right | Keep current widgets available. No fake universal File/Edit/View menus; Linux apps do not universally export app menus. |
| Dock | Centred floating panel, pinned and running apps, active indicators, tooltips, contextual actions, optional magnification and autohide | Focus/launch using existing application entries and compositor APIs. No fabricated native minimize/Genie behavior. |
| Control Center | One panel for audio, brightness, network, Bluetooth, battery/power status, night light, notification mode and now playing | Reuse available services; hide unsupported controls. Never claim Apple Continuity, AirDrop or AirPlay support. |
| Widgets | Clock, calendar and now playing first; optional weather and system/battery cards | Desktop placement and panel placement share the same components. Weather is opt-in and location is user-selected. |
| Music | Music-inspired artwork card with title, artist, supported playback controls, player chooser and Apple Music launch action | MPRIS-first; controls depend on the active browser/player's capabilities. See section 7. |
| File manager | Retain Nautilus; supported dark preference, consistent icon theme and modest Finder-inspired content treatment | No forced libadwaita CSS patching or silent default-manager switch. Exact Finder parity is not promised. |
| Notifications | Supported palette integration, DND controls and access to stock notification history | The installed full-bar facade exposes DND, not history/notification models. A custom grouped history renderer is deferred pending a supported API; do not scrape private storage or run a second server. |
| Launcher/menus | Preserve current commands and keybindings; coordinate supported theme colours | A true layout replacement requires a separately validated integration. Do not ship a lookalike search box that breaks existing shortcut workflows. |
| OSD | Coordinated volume/brightness feedback where the shell supports it | Avoid duplicate stock and custom OSDs. |
| Applications | Optional coherent GTK, Qt and terminal appearance adapters | Honour toolkit limitations and installed apps; preserve every app shortcut. Font changes are separately opt-in. |
| Lock screen | Keep stock secure locking; only existing supported palette/wallpaper integration | Never wrap, replace, or weaken authentication for appearance. |

### Dock behavior specification

- Pin, unpin and reorder applications, retaining desktop-entry IDs rather than hard-coded executable strings.
- Merge running windows with pinned items and handle multiple windows predictably.
- Offer Downloads and Trash entries using installed desktop services. Confirm destructive actions.
- Autohide in fullscreen and provide an optional always-visible mode with explicit reserved-screen-space behavior.
- Support a selected primary display or per-display docks, mixed DPI, hotplug and edge detection.
- Do not steal focus, cover lock surfaces, or capture keyboard input merely because the pointer crosses the dock.
- Preserve existing tiling; a dock is not permission to convert the system to floating windows.

### Widget extensibility specification

Create an internal module registry, not a second package manager:

- Stable widget ID, title, component, supported sizes and settings schema.
- Placement in the desktop grid or widget panel.
- Explicit data/service dependencies and opt-in network access where relevant.
- Start/stop behavior, bounded caches, error/empty/loading states.
- Common theme, accessibility and interaction contracts.
- Only bundled, reviewed code in v1. External modules are executable code and would need a separate trust model.

Future modules can include tasks, notes, world clocks, weather forecasts, disk/network status and integrations with existing Omarchy widgets. Keep personal calendar and account integration out of the default unauthenticated calendar widget.

## 5. Packaging and architecture

### Public installation target

```bash
omarchy plugin add https://github.com/Drona-Srivastava/mac-plugin.git --enable
```

Omarchy displays its normal trust/confirmation prompt. Its non-interactive `--yes` option is not the recommended default in public documentation.

The installed plugin is executable, unsandboxed user-session code. Its permissions and appearance changes must be documented clearly.

### One repository, one root manifest

Use a root `manifest.json` with `schemaVersion: 1`, a stable namespaced ID, descriptive version/name/author, supported `kinds` and relative `entryPoints`. The primary entry point is a full replacement **bar**. It owns the top bar and instantiates plugin-local dock, widgets, settings, and popups as needed. A combined `bar` + `service` + `panel` manifest is supported if shared models and a summoned settings panel warrant it; confirm the exact lifetime arrangement in Phase 0.

One repository exposes one plugin identity, one registered bar-widget entry if declared, one service entry and at most one host-managed panel/menu/overlay entry. Compose multiple windows inside these components. Internal widget modules do not automatically become independent Omarchy plugin IDs: nested manifests are not discovered for third-party repos.

Keep all declared files inside the repository, with no path traversal or symlinks. The installer rejects symlinks. Manifest version text is not an enforced compatibility range: the plugin must detect required versions/APIs and provide its own clear unsupported-version message.

Use QML/Qt Quick and available Quickshell modules. Prefer event-driven Hyprland, MPRIS, PipeWire, UPower and system-tray integrations over shell polling. Isolate Omarchy-specific host access behind adapters, and use only capabilities actually exposed to third-party plugins.

Preserve the replacement-bar widget contract so existing Omarchy and user widgets can render, use tooltips, open popups and retain settings. Service-backed widgets need explicit compatibility tests: replacement bars do not receive every privileged host object.

### Verified backend choices and limitations

- **Dock:** build the task/grouping model from `ToplevelManager`, Hyprland workspace/window data and `DesktopEntries`. There is no stock dock model to reuse. Prefer Omarchy-compatible `uwsm-app`/desktop-entry launching.
- **Media:** use `Quickshell.Services.Mpris` directly or the documented limited full-bar media proxy; an ordinary third-party service cannot freely obtain stock services.
- **Tray:** use `Quickshell.Services.SystemTray` and QML menu rendering via `QsMenuOpener`; native platform submenus cannot be assumed to work in this shell configuration.
- **Notifications:** use supported DND IPC and the stock `showHistory` action. A new fully integrated custom history requires an upstream supported API or a separately scoped replacement, not a v1 assumption.
- **Styling:** `qs.Commons` and `qs.Ui` expose theme tokens and controls, but plugin-specific Mac design tokens must remain independent of frozen application-window styling.
- **Lifecycle:** no install/uninstall hooks. Guard against host properties being injected after QML object creation. Avoid `keepLoaded` unless needed: it can retain old service code until a shell restart.
- **State:** never write caches/settings into the watched git source checkout. That can trigger reload loops, dirty updates and lost state on removal.

If a full replacement bar cannot preserve existing widgets through the exposed interfaces, the first preview must use an additive `bar-widget` + `service` + `panel` implementation and stock top bar rather than silently dropping working functionality. Full-bar compatibility remains a gate for the intended finished experience.

### Broader application appearance

Omarchy's plugin installer clones and validates files and enables the plugin. It does **not** run an install hook, install dependencies, perform privileged work, or automatically apply a theme.

Therefore:

1. The install command makes the shell experience available.
2. First launch presents a preview and an **Apply desktop appearance** action.
3. That action lists exact changes, creates backups and applies only the selected user-level adapters.
4. Optional packages are offered separately with normal Omarchy package workflows and confirmation.

No hidden bootstrap installer, download-and-execute pipeline, or first-run privileged operation.

### Proposed source layout

```text
manifest.json
Bar.qml
components/
  MenuBar.qml
  Dock.qml
  ControlCenter.qml
  WidgetHost.qml
  SettingsPanel.qml
  FirstRun.qml
  design/
widgets/
  Clock.qml
  Calendar.qml
  NowPlaying.qml
services/
  DesktopModel.qml
  MediaAdapter.qml
  SystemAdapter.qml
  SettingsAdapter.qml
appearance/
  theme/
  icons/
  wallpapers/
scripts/
  appearance-apply
  appearance-restore
  doctor
tests/
docs/
  INSTALL.md
  DESIGN.md
  COMPATIBILITY.md
  WIDGETS.md
  RECOVERY.md
.github/workflows/
README.md
LICENSE
THIRD_PARTY_NOTICES.md
CHANGELOG.md
```

These helper script names are proposed project interfaces, not existing Omarchy commands.

## 6. Reversible appearance and protected-style safeguards

### State ownership

- Runtime plugin preferences should use the supported inline host configuration contract where available. Confirm full-bar settings persistence before fixing the schema. Manifest defaults/settings schemas do not automatically produce a working settings UI in this release, and generic service/panel settings are not automatically injected. Implement the settings UI and defaults explicitly; if necessary use a documented isolated user configuration file outside the watched source checkout.
- Keep backup manifests and recovery data outside the git checkout, for example under `${XDG_STATE_HOME:-~/.local/state}/omarchy/plugins/drona.mac/`.
- Put generated theme assets in a new user-owned theme directory, never a stock theme directory.
- Never commit account tokens, hostnames, private user file paths, artwork caches, settings exports, SSH keys or local state.
- Use atomic writes, versioned data migrations and an explicit list of paths/keys owned by the plugin.

### Apply transaction

1. Check supported Omarchy/Quickshell versions and required APIs.
2. Inventory only relevant appearance state: shell layout, selected theme/background, toolkit appearance settings and effective protected Hyprland values.
3. Show a changes preview and obtain confirmation for changes outside the plugin's own live surfaces.
4. Save timestamped backup metadata and the prior values of each modified key/file.
5. Apply narrowly scoped changes, validate, and roll back that transaction on failure.
6. Verify unchanged global bindings and protected compositor values, including inherited/theme-derived values.

The installer selects the new `bar.id` before plugin QML can take its first backup. It cannot retrospectively discover a previously selected third-party full bar. On this machine the verified previous selection is the built-in bar. For other installations, document recording the prior selection before installing and offer selection of the restore target. Never claim an after-enable backup reconstructs all pre-install state.

### Theme interaction risk

The normal `omarchy theme set` pipeline regenerates Hyprland theme settings and reloads the compositor. The template derives active and inactive border settings from theme values. Merely leaving `~/.config/hypr/` untouched does **not** prove window styling is preserved.

Default strategy: keep the plugin's own palette independent, then apply only safe supported application appearance adapters. A full generated Omarchy theme is allowed only after tests prove it preserves all effective protected styling, including user overrides and theme-specific Lua. If safe preservation cannot be established, skip that adapter and explain the limitation rather than silently altering borders.

### Restore and removal

- Provide **Restore previous appearance** before plugin removal.
- Restore only values still matching what this plugin last wrote. If the user changed a value afterward, report a conflict rather than overwrite it.
- Preserve unrelated shell configuration and third-party widget entries.
- Provide a documented offline recovery helper for when the shell cannot load.
- Switching the active bar away unloads its surfaces, but does not by itself undo external GTK/icon/theme changes.
- The normal plugin remover has no custom uninstall transaction. Document appearance restoration separately; do not depend on QML destruction callbacks for reliable cleanup.

Emergency return to the stock bar uses the existing command:

```bash
omarchy plugin enable omarchy.bar
```

After restoring external appearance, normal removal is:

```bash
omarchy plugin remove drona.mac
```

Updates use `omarchy plugin update drona.mac`. The installed updater follows `origin HEAD`, not a semantic-version field or release tag, so keep `main` release-ready and use development branches for unfinished work. Switch to the stock bar and disable other references to this plugin before an update: validation happens after updating the watched checkout. Record the previous commit for rollback; do not treat post-update validation as a sandbox. Remove deletes git-managed checkouts, so local source modifications must be saved elsewhere first.

## 7. Apple Music / now-playing integration

### First release: useful without credentials

- Build a Music-inspired now-playing widget with cover art, track, artist, album and supported transport controls.
- Support all MPRIS players, with explicit player selection and deterministic automatic selection.
- Include an **Open Apple Music** action for `https://music.apple.com/` using the installed browser or an existing user web app.
- Test Apple Music web playback in the supported browser and verify what actually appears over MPRIS. Browser Media Session support does not guarantee full MPRIS functionality in every browser.
- Enable seek, shuffle, repeat and volume only when the selected player exposes them.
- Handle no-player, paused, unavailable metadata, multiple-player, offline and missing-artwork states.
- Do not scrape credentials or browser profiles. Do not treat a generic browser MPRIS identity as proof it is Apple Music.

### Later optional enhancement

Direct Apple Music catalog/library integration through MusicKit is a separate milestone. It requires verification of Apple's current platform support, developer-token issuance and signing-key custody, user authorization, subscription requirements and browser DRM support.

Never embed an Apple developer private key in a public plugin, ship a shared long-lived credential, or promise native Apple Music playback on Linux. Keep playback in a supported browser if the supported route requires it. A local credential-free MPRIS widget must remain fully usable when MusicKit integration is absent.

## 8. Implementation phases and exit criteria

### Phase 0 — specification and compatibility spike

Deliverables:

- Freeze the released macOS reference and create annotated dark-mode visual specifications.
- Define protected settings and before/after checks.
- Validate a minimal full-bar plugin with a second dock surface.
- Prove preserved third-party widget hosting, popup lifecycle, settings persistence and fallback.
- Test notification/media/control access and identify unsupported host APIs early.

**Exit:** the architecture is demonstrated on the installed version without editing packaged files or protected settings. Unsupported replacement surfaces move to a themed-stock fallback or a documented future milestone.

### Phase 1 — safe plugin foundation

Deliverables:

- Root manifest, plugin identity, theme tokens, error states and settings surface.
- First-run preview, backup/restore transaction engine and recovery documentation.
- One-command installation in a clean test profile.
- Layout preservation and stock-bar recovery.

**Exit:** install, restart, reload, switch-back and removal work without binding/styling drift or unrelated configuration loss.

### Phase 2 — top bar and dock

Deliverables:

- Omarchy-branded top bar and compatible widget hosting.
- Active-app label, date/time, tray and compact system controls.
- Dock pinning, running-app tracking, focus/launch, reorder, autohide and display settings.
- Reduced-motion/transparency settings.

**Exit:** everyday workflows work across multiple displays, fullscreen apps and mixed DPI; no persistent idle animation or focus theft.

### Phase 3 — coordinated panels and widget framework

Deliverables:

- Control Center and widget panel.
- Desktop clock/calendar widgets with move/resize/edit mode.
- Optional weather and system/battery cards.
- Supported notification/OSD appearance integration, with explicit fallbacks.

**Exit:** controls call real backends, unavailable features degrade gracefully, no duplicate notification server or competing OSD, and hidden widgets suspend unnecessary work.

### Phase 4 — Music widget

Deliverables:

- MPRIS adapter, artwork caching, transport controls and player chooser.
- Apple Music web launch action and documented tested browser behavior.
- Compact, desktop and expanded-panel variants sharing one state model.

**Exit:** supported local players and the chosen browser are tested; unsupported Apple Music capabilities are clearly labelled, not simulated.

### Phase 5 — application and file-manager appearance

Deliverables:

- User-approved dark-mode/icon/wallpaper adapters.
- Conservative Nautilus support and a published toolkit compatibility matrix.
- Optional Qt/terminal palettes without replacing user shortcuts or font choices.
- Protected-style verification and conflict-aware restore tests.

**Exit:** the desktop looks cohesive while the existing Hyprland decoration and behavior remain unchanged. No unsupported libadwaita hacks in the default path.

### Phase 6 — hardening and public release

Deliverables:

- CI, compatibility checks, screenshots/demo, installation and recovery docs.
- Asset/license review and third-party attribution.
- Clean-profile install/update/restore/remove test from the GitHub URL.
- SSH publication using the existing available identity, after approval to implement and publish.

**Exit:** all release gates below pass; publish a tagged release with explicit minimum versions and known limitations.

Suggested milestones: `v0.1` foundation/top-bar/dock preview; `v0.2` panels/widgets/Music; `v1.0` tested appearance adapters, recovery, documentation and hardening. These are scope milestones, not time estimates.

## 9. Validation and release gates

### Automated checks

- `omarchy plugin validate` against the repository root.
- QML formatting/linting with the correct installed import paths; manifest/schema checks.
- Unit tests for application identity, dock ordering, media capability gating and widget configuration migrations.
- Helper-script linting and apply/restore tests against temporary homes and fixture configuration files.
- Tests for idempotent application, interrupted writes, restore conflicts and absent optional dependencies.
- Tests proving unrelated configuration keys and third-party widgets survive.
- Asset provenance/license checks and secret scanning in CI.

### Session-level checks

- Before/after comparison of bindings and effective protected Hyprland settings.
- `hyprctl reload` followed by `hyprctl configerrors` after any explicitly approved Hyprland configuration change; resolve every introduced error.
- Install/enable, shell restart, hot reload, bar replacement, appearance restore, update and removal.
- Idle, lock/unlock, suspend/resume, fullscreen, display reconnect and multiple displays.
- Normal/high/fractional scale factors, long labels, non-English text, keyboard navigation, contrast and reduced-motion mode.
- Existing third-party widgets, stock menu shortcuts, tray menus and service-backed popups.
- No network, no battery, no Bluetooth, no brightness control, no MPRIS player and failed optional adapter.
- Measure cold startup, first-open latency, memory and CPU/GPU activity against stock Omarchy; set numeric budgets after the baseline spike. No hard performance claims before measurement.

### Public release process

1. Initialize the project repository without overwriting unrelated local work.
2. Add the SSH publishing remote: `git@github.com:Drona-Srivastava/mac-plugin.git`.
3. Verify the existing SSH agent/key has authorized repository access. Do not display, copy, commit or replace private keys, and do not disable host-key verification.
4. Inspect the full diff, tests, license inventory, screenshots and repository contents.
5. Push the approved implementation to `main`, tag the tested release, and publish release notes.
6. Validate installation from the public HTTPS URL in a clean Omarchy profile, plus the supported update and recovery workflow.

## 10. Open technical gates, not reasons to block planning

- Capture version-labelled visual reference examples for the verified Golden Gate release.
- Confirm full-bar persistence and service-facade compatibility on the target Omarchy release.
- Determine which notification, launcher and OSD presentation changes are possible without host patches or companion installs.
- Verify Apple Music browser-to-MPRIS behavior on the actual target browser.
- Prove external theme integration can preserve effective compositor styling; otherwise use narrower adapters.
- Decide whether true background blur is possible without changing protected compositor values; otherwise use tinted translucent/opaque materials.

Default implementation choices are conservative: retain Nautilus, preserve the current widget layout, use original/open assets, keep authentication and lock behavior stock, and make the Music widget MPRIS-first.

## 11. Reference sources

### Released macOS and design

- [Apple security releases — stable version and release dates](https://support.apple.com/en-us/100100)
- [Apple Developer releases — stable versus beta builds](https://developer.apple.com/news/releases/)
- [macOS 27 Golden Gate — current product/design overview](https://www.apple.com/os/macos/)
- [Apple Human Interface Guidelines: Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
- [Apple Human Interface Guidelines: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Apple Human Interface Guidelines: Motion](https://developer.apple.com/design/human-interface-guidelines/motion)
- [Add and customize Mac widgets](https://support.apple.com/guide/mac-help/add-and-customize-widgets-mchl52be5da5/mac)
- [Music MiniPlayer](https://support.apple.com/guide/music/use-music-miniplayer-mus71d7dcfce/mac)

### Music and integration contracts

- [Apple Music web player](https://music.apple.com/)
- [Apple Music web user guide](https://support.apple.com/en-us/guide/music-web/welcome/web)
- [MusicKit overview](https://developer.apple.com/musickit/)
- [Developer-token requirements](https://developer.apple.com/documentation/applemusicapi/generating-developer-tokens)
- [MusicKit user authorization](https://developer.apple.com/documentation/applemusicapi/user-authentication-for-musickit)
- [MPRIS player interface and capabilities](https://specifications.freedesktop.org/mpris-spec/latest/Player_Interface.html)
- [Reference Omarchy input-layout plugin](https://github.com/jwkicklighter/jwkicklighter.input-layout)

The installed Omarchy source is the primary compatibility reference for version 4.0.4-1. Recheck it when supporting additional releases instead of assuming internal APIs remain stable.
