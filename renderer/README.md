# Scoped Omarchy renderer clone

`Bar.qml` and `BarModel.js` originate from Omarchy **4.0.4-1**, copied from the user-owned result of `omarchy plugin clone omarchy.bar`. Packaged `/usr/share/omarchy` files were not edited. Upstream: <https://github.com/basecamp/omarchy>. The original MIT license is retained in `LICENSE.omarchy`.

Local changes are intentionally narrow:

1. Bound QML component scopes (`pragma ComponentBehavior: Bound`).
2. `transformBarConfig` hook for a detached presentation layout.
3. `toggleAppearanceTransparency` hook so existing bar actions adjust only plugin appearance.
4. `surfacesEnabled` gate for hidden component tests.
5. Distinct layer-surface namespaces. The existing `omarchy.bar` IPC name is retained for command compatibility.

The plugin root inherits this renderer directly. Do not load the packaged bar again inside another bar Loader: testing exposed invalid/stale widget contexts when hot-switching that arrangement.

Omarchy 4.0.4 can also retain stale shared widget components across bar swaps. The plugin detects a blank configured Omarchy menu after startup and requests one documented `rescanPlugins` operation. `scripts/refresh-widget-catalog` uses a runtime-only lock/cooldown to prevent reload loops. It does not restart the shell, modify configuration or access lock/authentication services. Returning to the stock bar uses the lock-aware restart helper documented in the repository.

When updating the upstream copy, review the full diff, preserve the copyright notice, rerun component and lifecycle tests, and do not silently assume compatibility with a new Omarchy version.
