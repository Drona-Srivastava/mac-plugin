# Recovery

## Switch back without losing your layout

```bash
omarchy plugin enable omarchy.bar
```

On Omarchy 4.0.4, hot-switching can leave stale panel routing. Run `omarchy restart shell` after the switch while unlocked, or use `bash ~/.config/omarchy/plugins/drona.mac/scripts/return-to-stock` to do both through supported commands. The supplied return button uses that helper. The restart command refuses to terminate an active secure lock client.

If you used another replacement bar before installing, use that plugin ID. Mac Desktop's arrangement is a presentation layer over the saved bar layout, so moving the clock for the Mac preset does not rewrite its saved placement. Your optional `bar.macDesktop` preferences remain for next time.

## Undo external colours

Before removing the plugin:

```bash
python3 ~/.config/omarchy/plugins/drona.mac/scripts/appearance restore
python3 ~/.config/omarchy/plugins/drona.mac/scripts/appearance restore --yes
```

The first command previews. The second restores unchanged owned values. Later user edits cause a conflict, not a force overwrite. Review the JSON report and [appearance safety contract](../appearance/SAFETY.md). Recovery data lives in the XDG state directory, not the source checkout.

The wallpaper asset is a manual option and is **not** covered by the appearance journal. Record your old wallpaper path before changing it, then use `omarchy theme bg set /path/to/previous-image` to return.

## Shell unavailable

1. Use an existing terminal or TTY; do not replace keyboard bindings to recover.
2. Copy `~/.config/omarchy/shell.json` to a backup.
3. Change only the `bar.id` value to `omarchy.bar` using a JSON-aware editor. Do not replace the whole layout with defaults.
4. Restart with `omarchy restart shell` **only when the session is unlocked**. Never kill a live lock client as a styling workaround.
5. Restore external colours using the helper, resolve any reported conflicts, then remove the plugin normally.

Do not run `omarchy refresh shell` as routine removal: that resets your layout. Do not edit `/usr/share/omarchy`.

## Remove

```bash
omarchy plugin enable omarchy.bar
omarchy plugin remove drona.mac
```

Git-managed plugin removal deletes the checkout. Save any local source edits first. Keep state journals until appearance restoration is complete. Deleting the source directory does not magically undo user configuration changes.
