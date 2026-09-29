# Compatibility and validation

## Initial target

- Omarchy 4.0.4-1, Quickshell 0.3.1-1, Hyprland 0.56.2-2.
- Python standard library for the opt-in appearance transaction.
- The original Omarchy font and installed desktop-entry icons; no bundled Apple fonts or icons.

`Bar.qml` inherits the scoped local renderer in `renderer/Bar.qml`, cloned through the supported Omarchy command and distributed with upstream licensing. It receives the host's scoped shell facade, widget catalog, registry and detached bar configuration. It adds its own active-app label and appearance button only in the **rendered** layout and retains the inherited panel-shortcut dispatch methods. The Omarchy 4.0.4 host and shared UI interfaces remain explicit compatibility dependencies.

A live test found that hot-switching back to the stock bar on Omarchy 4.0.4 can leave stale panel routing. `scripts/return-to-stock` and the settings return button switch the bar and perform a supported, lock-aware shell restart; this recovered normal panel routing in the test. Direct `omarchy plugin enable omarchy.bar` may require a subsequent `omarchy restart shell` while unlocked.

On a hot switch, the host can also retain stale widget component contexts. If the configured Omarchy logo is blank after settling, the plugin requests a documented catalog rescan. A runtime-only cooldown bounds that retry and prevents reload loops. The direct-inheritance renderer avoids nesting another live stock bar. The host's standard failed-bar fallback remains available, but this is not a security sandbox or proof of future-version compatibility.

## Third-party widgets

Existing configured widget entries and settings are preserved. Omarchy deliberately withholds arbitrary live service objects from widgets hosted by replacement bars. Widgets based on local processes, QML composition or standard Quickshell services normally work; a widget depending on its host's private service object may not. Report its ID and Omarchy version, and return to the stock bar rather than changing authentication/service boundaries.

## Verified checks

Automated coverage includes settings normalization, non-destructive presentation, dock app identity/grouping/reordering, shell-palette merging, idempotence, failed/interrupted appearance transactions, conflict handling, unsafe path rejection and wallpaper reproducibility. The hidden QML smoke test connects to Wayland for type support but keeps the dock/settings hidden and gates off all bar surfaces.

Read-only invariant comparison checks global keybinding definitions, hashes of files under the user's Hyprland configuration directory and selected effective border/gap/decoration/group values. It does not prove every property of arbitrary third-party applications.

## Manual test matrix

Before claiming broader support, exercise:

- Multi-monitor hotplug and fractional scaling (the initial development desktop has one 1920×1080 display).
- Dock autohide, menus, no focus theft and fullscreen behavior on each monitor.
- Long app names, missing icons, multiple windows, apps with unusual desktop-entry IDs.
- Pin/unpin, moving pins and an intentionally empty pin list.
- Existing widget popups and keybinding-triggered panels.
- Reduced motion/transparency, keyboard navigation and large text.
- Enable, stock-bar switch-back, re-enable, appearance apply/restore and plugin update.
- Suspend/resume and lock/unlock without replacing the lock implementation.

No claim is made that all hardware/monitor combinations or assistive technologies have been manually tested.

## Deliberate limitations

- The top bar is at the top while this plugin is active; the stock saved placement is retained.
- Stock panels keep their geometry/corner behavior. The helper applies colours only, avoiding any indirect Hyprland styling changes.
- No native Apple Liquid Glass refraction or macOS window animation is implemented.
- No native Music app, custom notification server, Finder replacement or third-party widget store.
- Wallpaper selection is manual and outside the colour helper's rollback transaction.
- Mac-like colours do not force unsupported applications into a uniform appearance.
