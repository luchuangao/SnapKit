#!/bin/bash
# Xcode uses the signed-in developer account for cloud Developer ID signing and notarization.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SNAPKIT_TEAM_ID:?Set the Apple Developer team ID}"
: "${SNAPKIT_SIGNING_IDENTITY:?Set an installed Apple Development or Developer ID signing identity}"
release_dir="${1:-$PWD/.build/notarization/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$release_dir"
release_dir="$(cd "$release_dir" && pwd)"
archive="$release_dir/SnapKit.xcarchive"
if [ -e "$archive" ]; then echo "Archive already exists: $archive" >&2; exit 1; fi
./Scripts/build.sh
mkdir -p "$archive/Products/Applications" "$archive/dSYMs"
ditto dist/SnapKit.app "$archive/Products/Applications/SnapKit.app"
binary_dir="$(swift build -c release --show-bin-path)"
if [ -d "$binary_dir/SnapKit.dSYM" ]; then ditto "$binary_dir/SnapKit.dSYM" "$archive/dSYMs/SnapKit.dSYM"; fi
python3 - "$archive" "$SNAPKIT_TEAM_ID" "$SNAPKIT_SIGNING_IDENTITY" <<'PY'
import datetime, pathlib, plistlib, subprocess, sys
archive=pathlib.Path(sys.argv[1]); team=sys.argv[2]; identity=sys.argv[3]
info_path=archive/'Products/Applications/SnapKit.app/Contents/Info.plist'
info=plistlib.loads(info_path.read_bytes())
def run(*args): return subprocess.check_output(args,text=True).strip()
sdk=run('xcrun','--sdk','macosx','--show-sdk-version')
xcode=run('xcodebuild','-version').splitlines()
info.update(CFBundleSupportedPlatforms=['MacOSX'],DTPlatformName='macosx',DTPlatformVersion=sdk,
            DTSDKName='macosx'+sdk,DTSDKBuild=run('xcrun','--sdk','macosx','--show-sdk-build-version'),
            DTXcode=''.join(xcode[0].split()[1].split('.')).ljust(4,'0'),
            DTXcodeBuild=xcode[1].split()[-1],BuildMachineOSBuild=run('sw_vers','-buildVersion'))
info_path.write_bytes(plistlib.dumps(info))
architectures=run('lipo','-archs',str(info_path.parent/'MacOS/SnapKit')).split()
properties=dict(ApplicationPath='Applications/SnapKit.app',Architectures=architectures,
                CFBundleIdentifier=info['CFBundleIdentifier'],CFBundleShortVersionString=info['CFBundleShortVersionString'],
                CFBundleVersion=info['CFBundleVersion'],SigningIdentity=identity,Team=team)
(archive/'Info.plist').write_bytes(plistlib.dumps(dict(ApplicationProperties=properties,ArchiveVersion=2,
    CreationDate=datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None),Name='SnapKit',SchemeName='SnapKit')))
(archive.parent/'ExportOptions.plist').write_bytes(plistlib.dumps(dict(method='developer-id',destination='upload',
    teamID=team,signingStyle='automatic',manageAppVersionAndBuildNumber=False)))
PY
codesign --force --options runtime --timestamp --sign "$SNAPKIT_SIGNING_IDENTITY" "$archive/Products/Applications/SnapKit.app"
codesign --verify --deep --strict "$archive/Products/Applications/SnapKit.app"
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$release_dir/Export" -exportOptionsPlist "$release_dir/ExportOptions.plist" -allowProvisioningUpdates
echo "Upload finished. Export and verify the notarized app when Apple finishes processing:"
printf 'xcodebuild -exportNotarizedApp -archivePath "%s" -exportPath "%s/Notarized"\n' "$archive" "$release_dir"
