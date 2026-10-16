# Developer ID signing and Apple notarization

The 1.1.2 (build 5) release uses a Developer ID Application signature, Hardened Runtime and an Apple notarization ticket stapled to `SnapKit.app`. The DMG and ZIP contain this exact notarized application. The outer DMG is a transport container, not a separately notarized installer package.

Verification after extracting or copying the app:

```sh
codesign --verify --deep --strict /path/to/SnapKit.app
xcrun stapler validate /path/to/SnapKit.app
spctl --assess --type execute --verbose=2 /path/to/SnapKit.app
```

Gatekeeper must report `accepted` and `source=Notarized Developer ID`. Notarization is not App Store review or a guarantee of complete functionality.

## Reproduce a release

Install full Xcode, sign into an Apple Developer account with permission to use Developer ID, and have a matching development signing identity available. Xcode can use its cloud-managed Developer ID certificate; exporting its private key is unnecessary.

```sh
SNAPKIT_TEAM_ID=YOUR_TEAM_ID \
SNAPKIT_SIGNING_IDENTITY='Apple Development: your identity' \
./Scripts/archive-release.sh .build/notarization/release
```

The script builds an archive and uploads it using Xcode's authenticated account. An upload success alone does not mean notarization has passed. Once processing completes, export the notarized application:

```sh
xcodebuild -exportNotarizedApp \
  -archivePath .build/notarization/release/SnapKit.xcarchive \
  -exportPath .build/notarization/release/Notarized
./Scripts/package-notarized.sh .build/notarization/release/Notarized/SnapKit.app
```

The packaging script checks the code signature, stapled ticket and Gatekeeper assessment before generating the DMG and ZIP. Do not run the ordinary build script over a notarized release: its default local build uses an ad-hoc signature. Keep signing credentials, Xcode distribution logs and archives out of Git.

Apple references: [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [Cloud-managed certificates](https://developer.apple.com/help/account/certificates/cloud-managed-certificates).
