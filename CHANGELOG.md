# Changelog

## 0.1.1 — 2026-09-30

- Refine the base appearance from the supplied reference: translucent top bar, colourful rounded dock tiles, gentle hover scaling, and original violet/cobalt/teal **Prism Night** wallpaper.
- Replace nested loading of the packaged bar with direct inheritance from a scoped, licensed local renderer clone.
- Detect blank widgets after hot-switching on Omarchy 4.0.4 and request a bounded catalog rescan; add cooldown and path-safety tests.
- Extend live readiness diagnostics and test cold-start/switch/re-enable behavior.
- Supersedes 0.1.0, whose shared-renderer integration could leave widgets blank after a cold-start hot switch. Use 0.1.1 rather than pinning 0.1.0.

## 0.1.0 — 2026-09-30

Initial **base-appearance preview**, not the complete roadmap.

### Added

- Dark Mac-inspired top-bar presentation built on the installed Omarchy renderer.
- Original Omarchy logo and existing configured widget entries retained.
- Active-app label, appearance panel and optional right-aligned clock arrangement.
- Native floating dock: installed-app pins, running-window grouping, focus/launch, context menu pinning/reordering, autohide, monitor selection and fullscreen hiding.
- Plugin-scoped reduced-transparency and reduced-motion settings.
- Explicit, reversible colour-only shell and supported GNOME dark preference adapters.
- Original CC0 Graphite Tide wallpaper and reproducible generator (manual selection).
- Lock-aware return-to-stock helper for the observed Omarchy 4.0.4 hot-switch panel-routing issue.
- Settings/dock unit tests, 35 isolated appearance tests, hidden QML smoke test, CI and protected-setting comparison utility.

### Verified on the initial development session

- Manifest validation and Qt 6 QML lint/creation checks.
- Live bar and dock loading; visible dock rendering and audio-panel shortcut routing.
- Return-to-stock helper restored normal stock panel routing.
- Live shell-colour apply/restore completed without conflicts.
- Hyprland configuration hashes, global keybinding definitions and checked effective styling values remained unchanged throughout.

### Deferred

Music, calendar/weather/desktop widgets, a custom Control Center, notification-history replacement, exact Finder styling, drag pin reordering, magnification and Downloads/Trash dock shortcuts. Multi-monitor/scaling/fullscreen/input edge cases need broader manual testing. No Apple assets or account integration are included.
