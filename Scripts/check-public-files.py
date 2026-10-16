#!/usr/bin/env python3
"""Check public files without printing matching values. This is a preflight, not a proof of secrecy."""
import argparse
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PATTERNS = {
    'private key': rb'-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED )?PRIVATE KEY-----',
    'GitHub token': rb'\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{30,})\b',
    'AWS access key': rb'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b',
    'service token': rb'\b(?:xox[baprs]-[A-Za-z0-9-]{15,}|AIza[0-9A-Za-z_-]{30,}|sk-(?:proj-|ant-)?[A-Za-z0-9_-]{24,})\b',
    'personal filesystem path': rb'/Users/[A-Za-z0-9._-]+/|/(?:private/)?var/folders/[A-Za-z0-9._-]+/',
}
PRIVATE_SUFFIXES = ('.p12', '.pfx', '.p8', '.key', '.pem', '.cer', '.mobileprovision', '.provisionprofile')
PRIVATE_NAMES = {'.netrc', '.npmrc', '.pypirc', 'credentials.json', 'secrets.json'}
PRIVATE_DIRS = {'.ssh', '.aws', '.release', 'secrets', 'credentials'}


def content_findings(data):
    findings = [label for label, pattern in PATTERNS.items() if re.search(pattern, data)]
    assignment = rb'''(?im)\b(?:password|passwd|client_secret|api_key|access_token|refresh_token|secret_key)\b\s*[:=]\s*["']([^\r\n"']{8,})["']'''
    for match in re.finditer(assignment, data):
        if not re.fullmatch(rb'(?:YOUR_[A-Z_]+|<[^>]+>|\$\{[^}]+\}|placeholder|example|change[_-]?me)', match[1], re.IGNORECASE):
            findings.append('credential literal')
            break
    return findings


def private_filename(name):
    parts = PurePosixPath(name).parts
    return any(part.lower() in PRIVATE_DIRS or part.lower().endswith(('.xcarchive', '.xcdistributionlogs', '.dsym')) for part in parts) or any(
        part.lower() in PRIVATE_NAMES or part.lower() == '.env' or part.lower().startswith('.env.') or
        '.keychain' in part.lower() or part.lower().endswith(PRIVATE_SUFFIXES) for part in parts)


def tracked_files(root=ROOT):
    data = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root)
    return [name.decode() for name in data.split(b'\0') if name]


def file_findings(path, label=None):
    label = label or path.name
    findings = []
    if private_filename(label):
        findings.append((label, 'private filename'))
    if path.is_symlink():
        return findings + [(label, 'unreviewed symbolic link')]
    if path.suffix.lower() == '.zip':
        with zipfile.ZipFile(path) as archive:
            for entry in archive.infolist():
                if entry.is_dir():
                    continue
                name = label + ':' + entry.filename
                if private_filename(entry.filename):
                    findings.append((name, 'private filename'))
                findings.extend((name, reason) for reason in content_findings(archive.read(entry)))
    else:
        findings.extend((label, reason) for reason in content_findings(path.read_bytes()))
    return findings


def history_findings():
    findings = []
    objects = subprocess.check_output(['git', 'rev-list', '--objects', '--all'], cwd=ROOT, text=True)
    for item in objects.splitlines():
        oid, _, name = item.partition(' ')
        if subprocess.check_output(['git', 'cat-file', '-t', oid], cwd=ROOT).strip() != b'blob':
            continue
        label = oid[:12] + ':' + name
        if private_filename(name):
            findings.append((label, 'private filename'))
        data = subprocess.check_output(['git', 'cat-file', 'blob', oid], cwd=ROOT)
        findings.extend((label, reason) for reason in content_findings(data))
    return findings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--history', action='store_true')
    parser.add_argument('--source-zip', type=Path)
    parser.add_argument('paths', type=Path, nargs='*')
    args = parser.parse_args()
    if args.history and (args.paths or args.source_zip):
        parser.error('--history must be used separately')
    if args.source_zip and args.paths:
        parser.error('--source-zip uses only Git-tracked source files')
    if args.history:
        findings = history_findings()
    else:
        files = [(ROOT / name, name) for name in tracked_files()] if not args.paths else [
            (file, str(file.relative_to(path.parent))) for path in args.paths for file in (sorted(path.rglob('*')) if path.is_dir() else [path]) if file.is_file()]
        findings = [finding for path, name in files for finding in file_findings(path, name)]
    if findings:
        for path, reason in findings:
            print(f'BLOCKED: {path}: {reason}', file=sys.stderr)
        return 1
    if args.source_zip:
        args.source_zip.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(args.source_zip, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            for path, name in files:
                archive.write(path, name)
    print('PASS: no configured sensitive patterns found. Signing certificate metadata remains public.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
