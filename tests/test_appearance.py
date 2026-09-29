"""Isolated appearance safety tests: no real settings/session commands are run."""

import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zlib

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("drona_appearance", str(ROOT / "scripts/appearance"))
spec = importlib.util.spec_from_loader(loader.name, loader)
appearance = importlib.util.module_from_spec(spec)
loader.exec_module(appearance)


class FakeSettings:
    def __init__(self):
        self.defaults = {"color-scheme": "'default'", "gtk-theme": "'Adwaita'"}
        self.user = {"color-scheme": None, "gtk-theme": "'Original GTK'"}
        self.calls = []
        self.failure = None
        self.fail_after_write = False
        self.locked = set()
        self.unavailable = set()

    def __call__(self, *args):
        self.calls.append(args)
        if args[0] == "dconf":
            assert args[1] == "read" and args[2].startswith(appearance.DCONF_PREFIX), args
            return self.user[args[2].rsplit("/", 1)[1]] or ""
        assert args[0] == "gsettings" and args[2] == appearance.SCHEMA, args
        action, key = args[1], args[3]
        assert key in appearance.PREFERENCES, args
        if key in self.unavailable:
            raise appearance.AppearanceError("No such key")
        if action == "get":
            return self.user[key] or self.defaults[key]
        if action == "writable":
            return "false" if key in self.locked else "true"
        assert action in ("set", "reset"), args
        failing = self.failure == key
        if failing:
            self.failure = None  # A one-shot failure; rollback can still succeed.
            if not self.fail_after_write:
                raise appearance.AppearanceError("Injected write failure")
        self.user[key] = args[4] if action == "set" else None
        if failing:
            raise appearance.AppearanceError("Injected failure after side effect")
        return ""

    @property
    def writes(self):
        return [call for call in self.calls if call[0] == "gsettings" and call[1] in ("set", "reset")]


class AppearanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="drona-appearance-test-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "home"
        self.home.mkdir()
        self.env = mock.patch.dict(os.environ, {"HOME": str(self.home), "XDG_CONFIG_HOME": "",
                                               "XDG_STATE_HOME": "", "GSETTINGS_BACKEND": "dconf"}, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)
        self.settings = FakeSettings()
        patch = mock.patch.object(appearance, "command", self.settings)
        patch.start()
        self.addCleanup(patch.stop)
        patch = mock.patch.object(appearance.shutil, "which", side_effect=lambda name: "/mock/bin/" + name)
        patch.start()
        self.addCleanup(patch.stop)
        source = Path(self.temp.name) / "Color.qml"
        source.write_text('path: root.home + "/.config/omarchy/shell.toml"\nfunction loadUserShell(raw)\n'
                          + "\n".join(f'"{s}.{k}"' for s, keys in appearance.ALLOWED.items() for k in keys))
        patch = mock.patch.object(appearance, "COLOR_SOURCE", source)
        patch.start()
        self.addCleanup(patch.stop)
        self.app = appearance.Appearance()

    def write_shell(self, data=b"# my settings\n[font]\nbase-size = 13\n", mode=0o640):
        self.app.shell.parent.mkdir(parents=True, exist_ok=True)
        self.app.shell.write_bytes(data)
        self.app.shell.chmod(mode)
        return data

    def apply(self, **kwargs):
        output, code = self.app.execute("apply", yes=True, **kwargs)
        self.assertEqual(code, 0, output)
        self.assertEqual(output["result"], "applied", output)
        return output

    def test_status_preview_and_dry_run_never_write(self):
        before = self.write_shell()
        for action, options in [("status", {}), ("apply", {}), ("restore", {}),
                                ("apply", {"yes": True, "dry_run": True})]:
            output, code = self.app.execute(action, **options)
            self.assertEqual(code, 0, output)
            self.assertTrue(output["dry_run"])
            self.assertFalse(self.app.state.exists())
            self.assertEqual(self.app.shell.read_bytes(), before)
            self.assertEqual(self.settings.writes, [])

    def test_apply_restore_exact_values_bytes_permissions_and_protected_files(self):
        original = self.write_shell(b'# retained comment\n[bar]\n  background  = "#998877"  # keep note\nsize-horizontal = 29\n\n[font]\nbase-size = 15\n[lock]\nbackground = "#abcdef"\n[polkit]\ntext = "#123456"\n[controls]\nfocus-border-width = 2\n')
        protected = {}
        for relative in (".config/omarchy/shell.json", ".config/hypr/bindings.lua", ".config/hypr/looknfeel.lua",
                         ".config/gtk-4.0/gtk.css", ".config/omarchy/current/theme/colors.toml"):
            path = self.home / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("untouched sentinel " + relative)
            protected[path] = path.read_bytes()
        output = self.apply()
        self.assertEqual(output["skipped"], [])
        self.assertEqual(output["changes"][-1]["values"]["bar.background"], '"#171b24"')
        text = self.app.shell.read_text()
        self.assertIn('  background  = "#171b24"  # keep note', text)
        for line in ('base-size = 15', 'size-horizontal = 29', 'background = "#abcdef"',
                     'text = "#123456"', 'focus-border-width = 2'):
            self.assertIn(line, text)
        self.assertEqual(self.settings.user, appearance.PREFERENCES)
        self.assertEqual(stat.S_IMODE(self.app.state.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(self.app.journal.stat().st_mode), 0o600)
        self.assertLessEqual(self.app.journal.stat().st_size, appearance.MAX_JOURNAL)
        self.assertEqual(self.app.load()["phase"], "active")
        result, code = self.app.execute("restore", yes=True)
        self.assertEqual(code, 0, result)
        self.assertEqual(self.app.shell.read_bytes(), original)
        self.assertEqual(stat.S_IMODE(self.app.shell.stat().st_mode), 0o640)
        self.assertEqual(self.settings.user, {"color-scheme": None, "gtk-theme": "'Original GTK'"})
        self.assertIn(("gsettings", "reset", appearance.SCHEMA, "color-scheme"), self.settings.writes)
        self.assertFalse(self.app.journal.exists())
        for path, value in protected.items():
            self.assertEqual(path.read_bytes(), value)

    def test_absent_shell_is_removed_and_no_shell_json_is_created(self):
        self.apply()
        self.assertTrue(self.app.shell.exists())
        self.assertFalse((self.app.shell.parent / "shell.json").exists())
        result, code = self.app.execute("restore", yes=True)
        self.assertEqual(code, 0, result)
        self.assertFalse(self.app.shell.exists())

    def test_idempotent_apply_retains_original_journal_and_restore_is_idempotent(self):
        self.apply()
        journal, shell = self.app.journal.read_bytes(), self.app.shell.read_bytes()
        count = len(self.settings.writes)
        output, code = self.app.execute("apply", yes=True)
        self.assertEqual((output["result"], code), ("already-applied", 0))
        self.assertEqual(self.app.journal.read_bytes(), journal)
        self.assertEqual(self.app.shell.read_bytes(), shell)
        self.assertEqual(len(self.settings.writes), count)
        self.app.execute("restore", yes=True)
        output, code = self.app.execute("restore", yes=True)
        self.assertEqual((output["result"], code), ("nothing-to-restore", 0))

    def test_preferences_already_dark_not_owned_or_pinned(self):
        self.settings.defaults = dict(appearance.PREFERENCES)
        self.settings.user = {key: None for key in appearance.PREFERENCES}
        output, code = self.app.execute("apply", yes=True, shell=False)
        self.assertEqual((output["result"], code), ("unchanged", 0))
        self.assertEqual(self.settings.writes, [])
        self.assertFalse(self.app.journal.exists())

    def test_restore_follows_new_default_for_previously_unset_value(self):
        self.apply(shell=False)
        self.settings.defaults["color-scheme"] = "'prefer-light'"
        result, code = self.app.execute("restore", yes=True)
        self.assertEqual(code, 0, result)
        self.assertIsNone(self.settings.user["color-scheme"])
        self.assertEqual(appearance.gnome_current("color-scheme")["effective"], "'prefer-light'")

    def test_later_edits_conflict_preserve_user_state_and_retain_partial_backup(self):
        original = self.write_shell()
        self.apply()
        self.app.shell.write_text(self.app.shell.read_text() + "\n# later unrelated user edit\n")
        edited = self.app.shell.read_bytes()
        self.settings.user["gtk-theme"] = "'Later GTK'"
        output, code = self.app.execute("restore", yes=True)
        self.assertEqual((output["result"], code), ("restore-conflicts", 2))
        self.assertEqual(len(output["conflicts"]), 2)
        self.assertEqual(self.app.shell.read_bytes(), edited)
        self.assertEqual(self.settings.user["gtk-theme"], "'Later GTK'")
        self.assertIsNone(self.settings.user["color-scheme"])
        self.assertEqual(len(self.app.load()["entries"]), 2)
        # Manual resolution to originals lets the helper finish without a force flag.
        self.app.shell.write_bytes(original)
        self.settings.user["gtk-theme"] = "'Original GTK'"
        output, code = self.app.execute("restore", yes=True)
        self.assertEqual(code, 0, output)
        self.assertFalse(self.app.journal.exists())

    def test_permission_change_is_a_restore_conflict(self):
        self.apply(gnome=False)
        self.app.shell.chmod(0o644)
        result, code = self.app.execute("restore", yes=True)
        self.assertEqual(code, 2, result)
        self.assertEqual(stat.S_IMODE(self.app.shell.stat().st_mode), 0o644)

    def test_reapply_after_later_edit_refuses_without_replacing_backup(self):
        self.apply(shell=False)
        journal = self.app.journal.read_bytes()
        self.settings.user["color-scheme"] = "'prefer-light'"
        result, code = self.app.execute("apply", yes=True)
        self.assertEqual((result["result"], code), ("restore-required", 2))
        self.assertEqual(self.app.journal.read_bytes(), journal)
        self.assertEqual(self.settings.user["color-scheme"], "'prefer-light'")

    def test_gsettings_failure_rolls_back_earlier_writes(self):
        self.settings.failure = "gtk-theme"
        result, code = self.app.execute("apply", yes=True)
        self.assertEqual((result["result"], code), ("apply-failed", 1))
        self.assertEqual(result["rollback"]["result"], "restored")
        self.assertEqual(self.settings.user, {"color-scheme": None, "gtk-theme": "'Original GTK'"})
        self.assertFalse(self.app.shell.exists())
        self.assertFalse(self.app.journal.exists())

    def test_keyboard_interrupt_rolls_back_and_write_ahead_failure_never_applies(self):
        original_command = self.settings
        def command(*args):
            if args[:2] == ("gsettings", "set") and args[3] == "gtk-theme":
                raise KeyboardInterrupt()
            return original_command(*args)
        with mock.patch.object(appearance, "command", side_effect=command):
            result, code = self.app.execute("apply", yes=True)
        self.assertEqual(code, 1, result)
        self.assertEqual(result["rollback"]["result"], "restored")
        self.assertIsNone(self.settings.user["color-scheme"])
        self.settings.calls.clear()
        with mock.patch.object(self.app, "save", side_effect=OSError("Journal disk is full")):
            with self.assertRaisesRegex(OSError, "disk is full"):
                self.app.execute("apply", yes=True)
        self.assertEqual(self.settings.writes, [])
        self.assertFalse(self.app.shell.exists())

    def test_command_failure_after_side_effect_is_also_rolled_back(self):
        self.settings.failure, self.settings.fail_after_write = "gtk-theme", True
        result, code = self.app.execute("apply", yes=True)
        self.assertEqual(code, 1, result)
        self.assertEqual(result["rollback"]["result"], "restored")
        self.assertEqual(self.settings.user, {"color-scheme": None, "gtk-theme": "'Original GTK'"})

    def test_shell_write_failure_rolls_back_preferences_and_cleans_temporary_file(self):
        original = self.write_shell()
        real_replace = appearance.os.replace
        def fail_shell(source, target):
            if target == self.app.shell:
                raise OSError("Injected atomic rename failure")
            return real_replace(source, target)
        with mock.patch.object(appearance.os, "replace", side_effect=fail_shell):
            result, code = self.app.execute("apply", yes=True)
        self.assertEqual(code, 1, result)
        self.assertEqual(result["rollback"]["result"], "restored")
        self.assertEqual(self.app.shell.read_bytes(), original)
        self.assertEqual(list(self.app.shell.parent.glob(".drona-mac-*")), [])
        self.assertEqual(self.settings.user, {"color-scheme": None, "gtk-theme": "'Original GTK'"})

    def test_failed_rollback_keeps_recoverable_journal(self):
        self.settings.failure = "gtk-theme"
        original_command = self.settings
        def command(*args):
            if args[:2] == ("gsettings", "reset"):
                raise appearance.AppearanceError("Backend currently unavailable")
            return original_command(*args)
        with mock.patch.object(appearance, "command", side_effect=command):
            result, code = self.app.execute("apply", yes=True)
        self.assertEqual(code, 1, result)
        self.assertEqual(result["rollback"]["result"], "restore-conflicts")
        self.assertEqual(self.app.load()["phase"], "restore-pending")
        result, code = self.app.execute("restore", yes=True)
        self.assertEqual(code, 0, result)
        self.assertIsNone(self.settings.user["color-scheme"])

    def test_write_ahead_journal_recovers_hard_interruption(self):
        entries, _ = self.app.prepare()
        with self.app.lock():
            journal = {"version": 1, "plugin": "drona.mac", "phase": "applying",
                       "config_home": str(self.app.config_home), "home": str(self.app.home),
                       "dconf_profile": "", "entries": entries}
            self.app.save(journal)
            self.app.set_value(entries[0], entries[0]["before"], entries[0]["after"])
        result, code = self.app.execute("apply", yes=True)
        self.assertEqual((result["result"], code), ("restore-required", 2))
        result, code = self.app.execute("restore", yes=True)
        self.assertEqual(code, 0, result)
        self.assertIsNone(self.settings.user["color-scheme"])
        self.assertFalse(self.app.shell.exists())

    def test_crash_after_restore_write_before_checkpoint_is_recognized(self):
        self.apply(shell=False)
        self.settings.user = {"color-scheme": None, "gtk-theme": "'Original GTK'"}
        count = len(self.settings.writes)
        result, code = self.app.execute("restore", yes=True)
        self.assertEqual(code, 0, result)
        self.assertEqual(len(self.settings.writes), count)

    def test_changed_since_preview_is_not_overwritten(self):
        entries, _ = self.app.prepare(gnome=False)
        self.write_shell(b"# concurrent edit\n")
        with self.assertRaisesRegex(appearance.AppearanceError, "changed since inspection"):
            self.app.set_value(entries[0], entries[0]["before"], entries[0]["after"])
        self.assertEqual(self.app.shell.read_bytes(), b"# concurrent edit\n")

    def test_concurrent_helper_lock_fails_closed(self):
        with self.app.lock():
            with self.assertRaisesRegex(appearance.AppearanceError, "Another appearance transaction"):
                self.app.execute("apply", yes=True)
        self.assertEqual(self.settings.writes, [])

    def test_missing_tools_and_unsupported_backend_are_skipped(self):
        with mock.patch.object(appearance.shutil, "which", return_value=None):
            result, code = self.app.execute("apply", shell=False)
        self.assertEqual(code, 0)
        self.assertEqual(result["changes"], [])
        self.assertIn("both required", result["skipped"][0]["reason"])
        self.assertEqual(self.settings.calls, [])
        with mock.patch.dict(os.environ, {"GSETTINGS_BACKEND": "memory"}):
            result, code = self.app.execute("apply", yes=True, shell=False)
        self.assertEqual(code, 1, result)
        self.assertEqual(self.settings.writes, [])

    def test_nonwritable_and_missing_keys_are_not_written(self):
        self.settings.locked.add("color-scheme")
        self.settings.unavailable.add("gtk-theme")
        result, code = self.app.execute("apply", yes=True, shell=False)
        self.assertEqual(code, 1, result)
        self.assertEqual(len(result["skipped"]), 2)
        self.assertEqual(self.settings.writes, [])

    def test_xdg_state_path_and_nondefault_shell_config_fail_closed(self):
        state = Path(self.temp.name) / "custom-state"
        config = Path(self.temp.name) / "custom-config"
        with mock.patch.dict(os.environ, {"XDG_STATE_HOME": str(state), "XDG_CONFIG_HOME": str(config)}):
            app = appearance.Appearance()
            output, code = app.execute("apply", yes=True)
            self.assertEqual(code, 0, output)
            self.assertEqual(app.journal.parent, state / "omarchy/plugins/drona.mac")
            self.assertIn("non-default XDG_CONFIG_HOME", output["skipped"][0]["reason"])
            self.assertFalse(config.exists())
            self.assertFalse((self.home / ".config").exists())
            self.assertEqual(app.execute("restore", yes=True)[1], 0)

    def test_changed_dconf_profile_rejects_journal_before_writing(self):
        self.apply(shell=False)
        journal = self.app.journal.read_bytes()
        count = len(self.settings.writes)
        with mock.patch.dict(os.environ, {"DCONF_PROFILE": "different-profile"}):
            with self.assertRaisesRegex(appearance.AppearanceError, "DCONF_PROFILE"):
                self.app.execute("restore", yes=True)
        self.assertEqual(self.app.journal.read_bytes(), journal)
        self.assertEqual(len(self.settings.writes), count)

    def test_relative_xdg_paths_use_spec_defaults(self):
        with mock.patch.dict(os.environ, {"XDG_STATE_HOME": "relative", "XDG_CONFIG_HOME": "other"}):
            app = appearance.Appearance()
            self.assertEqual(app.state_home, self.home / ".local/state")
            self.assertEqual(app.config_home, self.home / ".config")

    def test_checkout_state_is_refused_before_any_write(self):
        with mock.patch.dict(os.environ, {"XDG_STATE_HOME": str(ROOT / "never-create-appearance-state")}):
            app = appearance.Appearance()
            with self.assertRaisesRegex(appearance.AppearanceError, "outside the source checkout"):
                app.execute("apply", yes=True)
        self.assertFalse((ROOT / "never-create-appearance-state").exists())
        self.assertEqual(self.settings.writes, [])

    def test_symlink_and_hardlinked_shell_files_are_never_replaced(self):
        target = self.home / "target"
        target.write_text("sentinel")
        self.app.shell.parent.mkdir(parents=True)
        self.app.shell.symlink_to(target)
        result, code = self.app.execute("apply", yes=True, gnome=False)
        self.assertEqual(code, 1, result)
        self.assertTrue(self.app.shell.is_symlink())
        self.assertEqual(target.read_text(), "sentinel")
        self.app.shell.unlink()
        os.link(target, self.app.shell)
        result, code = self.app.execute("apply", yes=True, gnome=False)
        self.assertEqual(code, 1, result)
        self.assertEqual(target.read_text(), "sentinel")

    def test_symlink_state_is_rejected(self):
        target = Path(self.temp.name) / "redirect"
        target.mkdir()
        self.app.state.parent.mkdir(parents=True)
        self.app.state.symlink_to(target, target_is_directory=True)
        with self.assertRaisesRegex(appearance.AppearanceError, "symlink"):
            self.app.execute("apply", yes=True)
        self.assertEqual(list(target.iterdir()), [])

    def test_later_shell_symlink_is_a_restore_conflict(self):
        self.apply(gnome=False)
        self.app.shell.unlink()
        target = self.home / "new-target"
        target.write_text("leave alone")
        self.app.shell.symlink_to(target)
        result, code = self.app.execute("restore", yes=True)
        self.assertEqual(code, 2, result)
        self.assertEqual(target.read_text(), "leave alone")
        self.assertTrue(self.app.journal.exists())

    def test_oversize_or_ambiguous_shell_is_skipped_unchanged(self):
        for content in (b"x" * (appearance.MAX_FILE + 1), b"[bar]\n[bar]\n", b"[bar]\ntext = 'a'\ntext = 'b'\n",
                        b"[bar.nested]\ntext = 'x'\n", b"[bar]\ntext = '''multiline\nvalue'''\n"):
            with self.subTest(content=content[:60]):
                self.write_shell(content)
                result, code = self.app.execute("apply", yes=True, gnome=False)
                self.assertEqual(code, 1, result)
                self.assertEqual(self.app.shell.read_bytes(), content)
                self.assertFalse(self.app.journal.exists())

    def test_shell_schema_capability_gate_and_palette_allowlist(self):
        appearance.COLOR_SOURCE.write_text("unsupported future shell API")
        result, code = self.app.execute("apply", yes=True, gnome=False)
        self.assertEqual(code, 1, result)
        self.assertFalse(self.app.shell.exists())
        malicious = self.home / "unsafe-palette.toml"
        malicious.write_text('[lock]\ntext = "#ffffff"\n')
        with mock.patch.object(appearance, "PALETTE", malicious):
            with self.assertRaisesRegex(appearance.AppearanceError, "protected key"):
                appearance.palette_values()

    def test_corrupt_unknown_and_oversized_journals_preserved(self):
        with self.app.lock():
            pass
        for data in (b"broken-json", b'{"version": 99}', b"x" * (appearance.MAX_JOURNAL + 1)):
            self.app.journal.write_bytes(data)
            with self.assertRaises(appearance.AppearanceError):
                self.app.execute("restore", yes=True)
            self.assertEqual(self.app.journal.read_bytes(), data)
        self.assertEqual(self.settings.writes, [])

    def test_status_reports_restore_conflicts_without_mutating_journal(self):
        self.apply()
        self.app.shell.write_text("# user replaced it\n")
        journal = self.app.journal.read_bytes()
        count = len(self.settings.writes)
        output, code = self.app.execute("status")
        self.assertEqual(code, 0, output)
        self.assertIn("conflict", [entry["state"] for entry in output["entries"]])
        self.assertEqual(self.app.journal.read_bytes(), journal)
        self.assertEqual(len(self.settings.writes), count)

    def test_cli_main_defaults_to_json_status_and_explicit_dry_run_wins(self):
        for args in ([], ["apply"], ["apply", "--yes", "--dry-run"]):
            with contextlib.redirect_stdout(io.StringIO()) as stdout:
                self.assertEqual(appearance.main(args), 0)
            output = json.loads(stdout.getvalue())
            self.assertTrue(output["dry_run"])
            self.assertFalse(self.app.state.exists())
        self.assertEqual(self.settings.writes, [])

    def test_subprocess_cli_with_stub_commands_and_temporary_home(self):
        # Real process/argument parsing; all GNOME invocations terminate in this
        # temporary stub, never in a live gsettings/dconf executable or bus.
        bindir = self.home / "bin"
        bindir.mkdir()
        stub = "#!" + sys.executable + "\n" + '''import json, os, pathlib, sys
p = pathlib.Path(os.environ["HOME"]) / "stub-settings.json"
s = json.loads(p.read_text()) if p.exists() else {}
a = sys.argv[1:]
if pathlib.Path(sys.argv[0]).name == "dconf":
    print(s.get(a[1].rsplit("/", 1)[-1], ""))
elif a[0] == "writable":
    print("true")
elif a[0] == "get":
    print(s.get(a[2], "'default'" if a[2] == "color-scheme" else "'Adwaita'"))
else:
    if a[0] == "set": s[a[2]] = a[3]
    elif a[0] == "reset": s.pop(a[2], None)
    else: raise SystemExit("unexpected command")
    p.write_text(json.dumps(s))
'''
        for name in ("gsettings", "dconf"):
            (bindir / name).write_text(stub)
            (bindir / name).chmod(0o700)
        env = {**os.environ, "PATH": str(bindir)}
        def cli(*args):
            result = subprocess.run([sys.executable, str(ROOT / "scripts/appearance"), *args],
                                    env=env, capture_output=True, text=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            return json.loads(result.stdout)
        self.assertEqual(cli("apply", "--no-shell-palette")["result"], "preview")
        self.assertFalse((self.home / "stub-settings.json").exists())
        self.assertFalse(self.app.state.exists())
        self.assertEqual(cli("apply", "--yes", "--no-shell-palette")["result"], "applied")
        self.assertEqual(cli("status")["result"], "active")
        self.assertEqual(cli("restore", "--yes")["result"], "restored")
        self.assertEqual(json.loads((self.home / "stub-settings.json").read_text()), {})

    def test_palette_merge_keeps_existing_crlf_comments_and_missing_final_newline(self):
        original = self.write_shell(b'[bar]\r\ntext = "#000000" # note\r\n[font]\r\nbase-size = 14')
        self.apply(gnome=False)
        self.assertIn(b'text = "#edf1f8" # note\r\n', self.app.shell.read_bytes())
        self.assertIn(b"base-size = 14\n", self.app.shell.read_bytes())
        self.app.execute("restore", yes=True)
        self.assertEqual(self.app.shell.read_bytes(), original)

    def test_wallpaper_png_integrity_dimensions_and_reproducible_generator(self):
        data = (ROOT / "appearance/wallpapers/graphite-tide.png").read_bytes()
        self.assertTrue(data.startswith(b"\x89PNG\r\n\x1a\n"))
        offset, pixels = 8, bytearray()
        while offset < len(data):
            length = struct.unpack("!I", data[offset:offset + 4])[0]
            kind = data[offset + 4:offset + 8]
            payload = data[offset + 8:offset + 8 + length]
            crc = struct.unpack("!I", data[offset + 8 + length:offset + 12 + length])[0]
            self.assertEqual(crc, zlib.crc32(kind + payload))
            if kind == b"IHDR":
                self.assertEqual(struct.unpack("!2I5B", payload), (2560, 1600, 8, 2, 0, 0, 0))
            if kind == b"IDAT":
                pixels.extend(payload)
            offset += length + 12
        self.assertEqual(len(zlib.decompress(pixels)), 1600 * (2560 * 3 + 1))
        generator_spec = importlib.util.spec_from_file_location("wallpaper_generator", ROOT / "appearance/generate_wallpaper.py")
        generator = importlib.util.module_from_spec(generator_spec)
        generator_spec.loader.exec_module(generator)
        self.assertEqual(generator.render(32, 20), generator.render(32, 20))


if __name__ == "__main__":
    unittest.main()
