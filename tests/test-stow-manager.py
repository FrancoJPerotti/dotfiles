"""Integration checks with real GNU Stow and isolated HOME directories."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'stow-manager'


class StowManagerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / 'repo'
        self.home = self.root / 'home'
        self.home.mkdir()
        self.repo.mkdir()
        shutil.copy2(SCRIPT, self.repo / 'stow-manager')
        (self.repo / 'common').mkdir()
        self.source = self.repo / 'test/app/.config/app'
        self.source.mkdir(parents=True)
        (self.source / 'config with spaces').write_text('repository')
        self.target = self.home / '.config/app'
        self.target.mkdir(parents=True)
        self.config = self.target / 'config with spaces'
        self.config.write_text('local')

    def run_manager(self, *args, env_extra=None):
        env = dict(os.environ, HOME=str(self.home))
        env.update(env_extra or {})
        return subprocess.run(['bash', str(self.repo / 'stow-manager'), 'test', *args],
                              env=env, text=True, capture_output=True)

    def backups(self):
        return list((self.home / '.local/state/dotfiles/backups').glob('*/test/app/.config/app/config with spaces'))

    def test_backup_shared_directory_and_idempotence(self):
        (self.target / 'unmanaged').write_text('keep')
        result = self.run_manager()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.config.is_symlink())
        self.assertEqual(self.config.read_text(), 'repository')
        self.assertEqual(self.backups()[0].read_text(), 'local')
        self.assertEqual((self.target / 'unmanaged').read_text(), 'keep')
        self.assertEqual(self.run_manager().returncode, 0)
        self.assertEqual(len(self.backups()), 1)
        self.assertEqual(self.run_manager('--unstow').returncode, 0)
        self.assertFalse(self.config.exists())
        self.assertEqual(self.backups()[0].read_text(), 'local')

    def test_dry_run(self):
        result = self.run_manager('-n')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Would back up: .config/app/config with spaces', result.stdout)
        self.assertEqual(self.config.read_text(), 'local')
        self.assertFalse(self.config.is_symlink())
        self.assertFalse((self.home / '.local').exists())

    def test_external_symlink(self):
        external = self.root / 'external'
        external.write_text('external')
        self.config.unlink()
        self.config.symlink_to(external)
        result = self.run_manager()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.backups()[0].is_symlink())
        self.assertEqual(external.read_text(), 'external')
        self.assertEqual(self.config.read_text(), 'repository')

    def test_blocking_parent_file(self):
        self.config.unlink()
        self.target.rmdir()
        self.target.write_text('blocked parent')
        result = self.run_manager()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.config.read_text(), 'repository')
        backups = list((self.home / '.local/state/dotfiles/backups').glob('*/test/app/.config/app'))
        self.assertEqual(backups[0].read_text(), 'blocked parent')

    def test_failed_stow_restores_backup(self):
        bin_dir = self.root / 'bin'
        bin_dir.mkdir()
        wrapper = bin_dir / 'stow'
        real = shutil.which('stow')
        wrapper.write_text('#!/bin/bash\nfor arg in "$@"; do\n'
                           '  if [[ "$arg" == "-nv" ]]; then exec "' + real + '" "$@"; fi\n'
                           'done\necho "Injected failure" >&2\nexit 2\n')
        wrapper.chmod(0o755)
        result = self.run_manager(env_extra={'PATH': str(bin_dir) + os.pathsep + os.environ['PATH']})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.config.read_text(), 'local')
        self.assertFalse(self.config.is_symlink())
        self.assertEqual(self.backups(), [])


if __name__ == '__main__':
    unittest.main()
