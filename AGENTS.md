# Public release privacy

The user requires sensitive information to stay out of GitHub and public downloads.

- Never commit or package passwords, access tokens, signing private keys, account credentials, keychains, provisioning profiles, private environment files, local logs, archives or personal filesystem paths.
- Use environment variables, the macOS Keychain and Xcode's authenticated account for signing. Documentation examples must use placeholders. The public certificate carried by a signed app is required for verification; it is not a private signing key.
- Before pushing, run `python3 Scripts/check-public-files.py --history` and `python3 Scripts/check-public-files.py`. Before uploading downloads, scan the packaged app and ZIPs with the same script. Fix any findings before publishing; do not print secret values in logs or chat.
- Release executables must omit local debug paths. Source archives must include only reviewed Git-tracked files, never recursively zip a working directory.
- Do not rewrite shared Git history or revoke credentials without the user's explicit instruction. Report any historical exposure that requires those actions.
