import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'
sys.path.insert(0, str(SCRIPTS))
from installer_icons import appimage_icon, local_icon, replace_icon

spec = importlib.util.spec_from_file_location('installer', SCRIPTS / 'app-installer.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class IconTests(unittest.TestCase):
    def test_replace_preserves_exec_and_actions(self):
        text = '[Desktop Entry]\nName=Example\nExec="/app with spaces/run" %U\n[Desktop Action Edit]\nIcon=edit\n'
        result = replace_icon(text, '/icons/app.png')
        self.assertIn('Exec="/app with spaces/run" %U', result)
        self.assertIn('Icon=/icons/app.png\n[Desktop Action Edit]', result)
        self.assertTrue(result.endswith('Icon=edit\n'))

    def test_extracted_layout(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            executable = root / 'usr/bin/example'
            executable.parent.mkdir(parents=True)
            executable.touch()
            executable.chmod(0o755)
            desktop = root / 'usr/share/applications/example.desktop'
            desktop.parent.mkdir(parents=True)
            desktop.write_text('[Desktop Entry]\nName=Example\nExec=/usr/bin/example %U\nIcon=/usr/share/icons/example.png\n')
            icon = root / 'usr/share/icons/example.png'
            icon.parent.mkdir(parents=True)
            icon.touch()
            with patch.object(installer, 'write_desktop') as write:
                self.assertTrue(installer.register_extracted(root, 'Example'))
                write.assert_called_once_with('Example', executable, icon)

    def test_icon_cannot_escape_package(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'package'
            root.mkdir()
            outside = Path(directory) / 'outside.png'
            outside.touch()
            (root / 'outside.png').symlink_to(outside)
            self.assertIsNone(local_icon(root, root / 'app.desktop', 'outside.png'))

    def test_missing_extractor_is_reported(self):
        with patch('installer_icons.shutil.which', return_value=None):
            with self.assertRaisesRegex(RuntimeError, '7zip'):
                appimage_icon(Path('/app.AppImage'), Path('/icons'))

    def test_dotted_icon_name_and_spaces(self):
        with tempfile.TemporaryDirectory(prefix='icons with spaces ') as directory:
            root = Path(directory)
            icon = root / 'org.example.App.png'
            icon.touch()
            self.assertEqual(local_icon(root, root / 'app.desktop', 'org.example.App'), icon)

    def test_missing_icon(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertIsNone(local_icon(root, root / 'app.desktop', 'missing'))


if __name__ == '__main__':
    unittest.main()
