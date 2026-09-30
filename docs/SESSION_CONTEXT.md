# Session Context

Updated: 2026-09-30 23:25 IST

## Objective

Build the existing `Drona-Srivastava/mac-plugin` into a polished Omarchy desktop package with a persistent widget layer, retaining plugin ID `drona.mac` and the current bar/dock experience.

## Current implementation

- Existing bar and dock from `v0.1.1` remain in place.
- Manifest now declares both `bar` and `service`; the service owns desktop layer surfaces.
- New `DesktopWidgets.qml` creates separate `WlrLayer.Bottom` windows on the selected monitor (first monitor by default).
- Initial cards: clock, Open-Meteo weather (with Omarchy location), month calendar, CPU/memory/disk/battery/GPU/temperature, and MPRIS music.
- Preferences are still stored in `bar.macDesktop` through the existing Omarchy bar configuration. New keys control the overall layer, individual cards, and clock format.
- Cards are independent layer-shell windows, so empty desktop regions are not covered by a fullscreen input surface.

## Design decisions

- Keep the existing repository URL and `drona.mac` identity; display branding is moving toward “Luxe Desktop for Omarchy”.
- Keep Omarchy's current bar and launcher behavior; no Hyprland config, keybindings, global blur, or window decoration changes.
- Weather reads Omarchy's shared weather location state and queries Open-Meteo for current conditions and daily high/low every 30 minutes; it falls back to Omarchy's status helper if coordinates are absent. It does not store credentials.
- System card reads `/proc`, `df`, UPower, NVIDIA tooling, and sensors when present, at a 15-second sample interval. NVIDIA command output is validated; this machine's installed `nvidia-smi` cannot talk to the driver, so GPU usage shows unavailable.
- QML/JavaScript within the existing Quickshell process; no standalone widget daemon.

## Dependencies

Omarchy 4.0.4, Quickshell 0.3.1, Hyprland 0.56.2 are the local baseline. Existing `omarchy-weather-status`, `sh`, `awk`, `df`, `curl`, `jq`, `nvidia-smi`, and `sensors` are runtime/environment facilities; GPU and sensor tools are optional. MPRIS and UPower are Quickshell services.

## Known issues and validation state

- The source repo lives at `/home/nova/.config/omarchy/plugins/drona.mac`, outside the writable project root. Work is being staged in `/home/nova/Projects/Enhance shih/omarchy-luxe`; changes must be transferred back after an approved write operation.
- The isolated Quickshell smoke test passed after the final widget changes and loaded both the bar and desktop service. The actual Omarchy shell remains stopped, so plugin-manager activation and visible layer/input behavior were not verified.
- The implementation is committed locally in the target checkout. A push to the specified GitHub remote could not authenticate: `gh auth status` reports no logged-in host, and Git cannot prompt for credentials in this session.
- Validate whether the injected service facade's `barConfig.macDesktop` binding updates after a settings change. If not, connect service preferences to a suitable supported host update mechanism without widening the plugin's permissions.
- Verify actual MPRIS method/property names with Qt 6 QML lint and an active session.
- Confirm QML attachment of children to `PanelWindow`, layer ordering, input bounds, multiple displays, and fullscreen behavior on a live Hyprland session.
- `omarchy plugin validate .`, the Node tests, all 38 Python tests, and the isolated Wayland smoke test pass in the staged checkout.
- `qmllint` and `qmlformat` parse the new QML. The only remaining lint warnings are the unresolved `PanelWindow` type/margins metadata also seen with Omarchy's standard layer-shell components.

## Files added or changed in this implementation

Manifest, `Service.qml`, `DesktopWidgets.qml`, widget card QML components, `services/Preferences.js`, `components/SettingsPanel.qml`, `Bar.qml`, README, PLAN, CHANGELOG, tests, install/contribution docs, and session notes.

## Commands used

Inspected Omarchy plugin docs and installed service APIs under `/usr/share/omarchy/shell`; ran `omarchy plugin validate .`, QML lint/format, Node/Python tests, and the elevated isolated `scripts/smoke-test`; checked Quickshell and Hyprland versions and local weather/system tools.

## Next steps

After GitHub authentication, push the local `main` commit with a normal fast-forward push. Then test plugin-manager activation, settings propagation, visible layer/input behavior, service failure isolation, and disable/remove behavior before considering a release.
