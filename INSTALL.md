# Install and remove

The plugin is distributed through Omarchy's plugin manager:

```bash
omarchy plugin add https://github.com/Drona-Srivastava/mac-plugin.git --enable
```

Omarchy displays a third-party plugin warning and installs the repository as user-session QML. Review the source before enabling. The plugin manager does not install system packages or modify Hyprland configuration.

The selected `drona.mac` bar includes the pinned widget service. Open the settings panel from its sliders button to disable the full widget layer or individual cards. Widget preferences remain in the existing `bar.macDesktop` namespace in `~/.config/omarchy/shell.json`.

To return to the built-in bar and remove the plugin:

```bash
bash ~/.config/omarchy/plugins/drona.mac/scripts/return-to-stock
omarchy plugin remove drona.mac
```

Appearance changes applied with the optional appearance helper are separate from plugin removal. Restore those explicitly before removing the checkout:

```bash
python3 ~/.config/omarchy/plugins/drona.mac/scripts/appearance restore --yes
```

No wallpaper is automatically installed or selected. For recovery details and the Omarchy 4.0.4 bar-switch caveat, see [RECOVERY.md](docs/RECOVERY.md).
