# Contributing

Changes should work with the documented Omarchy, Quickshell, and Hyprland compatibility target and preserve existing bar layouts, keybindings, Hyprland styling, and user preferences.

Before opening a pull request, run:

```bash
omarchy plugin validate .
node tests/test_preferences.cjs
node --test tests/dock-helpers.test.mjs
python3 -m unittest discover -s tests -v
scripts/smoke-test
```

For changes to widgets, test offline behavior, unavailable hardware/player services, reduced transparency, multiple monitors, fullscreen windows, and plugin disable. Do not include credentials, private machine snapshots, or generated restore journals. Use original or permissively licensed assets and add attribution to `THIRD_PARTY_NOTICES.md` when required.

Keep each widget independent so an unavailable data source cannot prevent the rest of the shell from loading. Prefer Omarchy and Quickshell APIs over global config edits or additional resident processes.
