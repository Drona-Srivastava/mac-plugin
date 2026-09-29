import importlib.machinery
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

path = Path(__file__).resolve().parents[1] / 'scripts/refresh-widget-catalog'
loader = importlib.machinery.SourceFileLoader('catalog_refresh', str(path))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)


class CatalogRefreshTests(unittest.TestCase):
    def test_rescan_is_bounded_and_reset_requires_no_command(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {'XDG_RUNTIME_DIR': tmp}), \
                mock.patch.object(module.subprocess, 'run', return_value=mock.Mock(returncode=0)) as run:
            self.assertEqual(module.refresh(), 0)
            self.assertEqual(module.refresh(), 0)
            self.assertEqual(run.call_count, 1)
            self.assertEqual(run.call_args.args[0], ['omarchy-shell', 'shell', 'rescanPlugins'])
            self.assertEqual(module.refresh(reset=True), 0)
            self.assertEqual(run.call_count, 1)
            self.assertEqual(module.refresh(), 0)
            self.assertEqual(run.call_count, 2)

    def test_missing_runtime_fails_without_command(self):
        with mock.patch.dict(os.environ, {'XDG_RUNTIME_DIR': ''}), mock.patch.object(module.subprocess, 'run') as run:
            self.assertEqual(module.refresh(), 1)
            run.assert_not_called()

    def test_symlink_cannot_redirect_runtime_marker(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {'XDG_RUNTIME_DIR': tmp}):
            victim = Path(tmp) / 'unrelated'
            victim.write_text('keep')
            (Path(tmp) / 'drona-mac-catalog.lock').symlink_to(victim)
            with self.assertRaises(OSError):
                module.refresh()
            self.assertEqual(victim.read_text(), 'keep')
