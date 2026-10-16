# Public release privacy

Release 1.1.2 removes local build paths from the distributed executable. Debug symbols stay outside the app. Source ZIPs now use only Git-tracked files, and a preflight checks the source and application before packaging. CI also runs this preflight and its regression tests.

The audit of SnapKit's source history and the 1.1.0/1.1.1 source ZIPs found no matches for the checked credential formats or private key headers. The old application executables contained local debug paths; their binary downloads have been withdrawn in favor of 1.1.2. This audit does not establish that arbitrary secrets can never be present.

```sh
python3 Scripts/check-public-files.py
python3 Scripts/check-public-files.py --history
python3 Scripts/check-public-files.py dist/SnapKit.app dist/SnapKit-1.1.2-macOS-arm64.zip
python3 -m unittest discover -s Scripts/tests -p 'test_*.py'
```

Keep account credentials in Keychain or environment variables. Do not stage local logs, development archives, private environment files or signing keys. The public certificate embedded in a signed application includes the developer's public signing identity and team identifier; this information is necessary for signature verification and contains no signing private key.

Normal updates and withdrawing downloads do not erase prior Git objects or previously downloaded copies. The website repository's older commits still contain the previous installers and their debug paths. A complete history purge would require a separately authorized history rewrite and coordinated updates of affected clones.
