import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('public_files', Path(__file__).resolve().parents[1] / 'check-public-files.py')
scanner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scanner)


class PublicFilesTests(unittest.TestCase):
    def test_credentials_are_detected_without_disclosing_values(self):
        token = b'ghp_' + b'A' * 36
        self.assertEqual(scanner.content_findings(token), ['GitHub token'])
        private_key = b'-----BEGIN ' + b'PRIVATE KEY-----'
        self.assertIn('private key', scanner.content_findings(private_key))

    def test_local_paths_are_detected(self):
        path = b'/' + b'Users' + b'/example/build/file.o'
        self.assertIn('personal filesystem path', scanner.content_findings(path))
        self.assertFalse(scanner.content_findings(b'/System/Library/Frameworks/AppKit.framework'))

    def test_credential_literals_and_placeholders(self):
        value = b'password=' + b'"' + b'private-example-value' + b'"'
        self.assertIn('credential literal', scanner.content_findings(value))
        json_value = b'{"client_secret":' + b'"' + b'private-example-value' + b'"}'
        self.assertIn('credential literal', scanner.content_findings(json_value))
        self.assertFalse(scanner.content_findings(b'api_key="YOUR_API_KEY"'))

    def test_private_file_types_and_directories(self):
        for name in ['Scripts/.env.local', 'signing.P12', 'private.keychain-db', '.release/export.log', 'Secrets/account.json']:
            with self.subTest(name=name):
                self.assertTrue(scanner.private_filename(name))
        self.assertFalse(scanner.private_filename('Resources/Info.plist'))

    def test_zip_entries_are_checked(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'source.zip'
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr('Scripts/.env', 'placeholder')
                archive.writestr('README.md', b'ghp_' + b'A' * 36)
            findings = scanner.file_findings(path)
            self.assertEqual({reason for _, reason in findings}, {'private filename', 'GitHub token'})

    def test_untracked_files_cannot_enter_source_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            (root / 'README.md').write_text('Public source')
            subprocess.run(['git', 'add', 'README.md'], cwd=root, check=True)
            (root / '.env').write_text('private placeholder')
            self.assertEqual(scanner.tracked_files(root), ['README.md'])


if __name__ == '__main__':
    unittest.main()
