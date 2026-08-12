set -euxo pipefail

nogvr=false

if [ "${1:-}" == "nogvr" ]; then
    nogvr=true
    shift
fi

rustup target add \
    aarch64-linux-android \
    armv7-linux-androideabi \
    x86_64-linux-android \
    i686-linux-android

# Prepare ALVR dependencies
pushd ALVR
cargo update
cargo xtask prepare-deps --platform android "$@"
popd

# Remove old Cardboard build if present
rm -rf cardboard

# Download Cardboard SDK source
CARB_REPO_NAME="cardboard-master"
rm -rf "${CARB_REPO_NAME}"

curl -sLS "https://github.com/nift4/cardboard/archive/refs/heads/master.zip" > download.zip
unzip download.zip
rm download.zip

# Build Cardboard SDK
pushd "${CARB_REPO_NAME}"
chmod +x ./gradlew
./gradlew sdk:assembleRelease -Parm64-v8a
popd

# Prepare Cardboard files
mkdir -p cardboard

mv "${CARB_REPO_NAME}/sdk/build/outputs/aar/sdk-release.aar" \
   cardboard/cardboard-sdk.aar

cp "${CARB_REPO_NAME}/sdk/include/cardboard.h" \
   cardboard/cardboard.h

# Verify that the AAR really exists
test -f cardboard/cardboard-sdk.aar
ls -lh cardboard/cardboard-sdk.aar

rm -rf "${CARB_REPO_NAME}"

# Legacy Google VR SDK is only needed for GVR builds
rm -rf "gvr-android-sdk-1.200"

if [ "$nogvr" != true ]; then
    curl -sLS "https://github.com/googlevr/gvr-android-sdk/releases/download/v1.200/gvr-android-sdk-1.200.zip" > download.zip
    unzip download.zip
    rm download.zip
fi
