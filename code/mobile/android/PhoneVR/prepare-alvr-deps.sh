#!/usr/bin/env bash

set -euxo pipefail

# Work around OpenJDK cgroup/container metrics crash
# on current GitHub Actions runners.
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -XX:-UseContainerSupport"

nogvr=false

if [ "${1:-}" == "nogvr" ]; then
    nogvr=true
    shift
fi


# ============================================================
# Rust Android targets
# ============================================================

rustup target add \
    aarch64-linux-android \
    armv7-linux-androideabi \
    x86_64-linux-android \
    i686-linux-android


# ============================================================
# Prepare ALVR tools
# ============================================================

pushd ALVR

git submodule update --init --recursive

# PhoneVR's ALVR fork uses the pre-v4 cargo-ndk CLI:
#
#   -p 26
#   --no-strip
#
# cargo-ndk v3.5.7 is yanked from crates.io, so install it
# directly from its GitHub tag instead.
cargo install \
    --git https://github.com/bbqsrc/cargo-ndk \
    --tag v3.5.7 \
    --locked \
    --force \
    cargo-ndk

cargo install cbindgen \
    --locked \
    --force

cargo ndk --version
cbindgen --version

popd


# ============================================================
# Prepare Cardboard SDK
# ============================================================

rm -rf cardboard

CARB_REPO_NAME="cardboard-master"

rm -rf "${CARB_REPO_NAME}"
rm -f download.zip


# Download Cardboard SDK source
curl \
    --fail \
    --location \
    --show-error \
    --silent \
    "https://github.com/nift4/cardboard/archive/refs/heads/master.zip" \
    --output download.zip

unzip -tq download.zip
unzip download.zip
rm -f download.zip


# ============================================================
# Only configure the Cardboard SDK project.
# Do not configure hellocardboard-android.
# ============================================================

echo "include ':sdk'" > "${CARB_REPO_NAME}/settings.gradle"

echo "============================================"
echo "Cardboard settings.gradle:"
cat "${CARB_REPO_NAME}/settings.gradle"
echo "============================================"


# ============================================================
# Build Cardboard SDK
# ============================================================

pushd "${CARB_REPO_NAME}"

chmod +x ./gradlew

./gradlew \
    :sdk:assembleRelease \
    -Parm64-v8a \
    --no-daemon \
    --stacktrace

popd


# ============================================================
# Copy Cardboard outputs required by PhoneVR
# ============================================================

mkdir -p cardboard

mv \
    "${CARB_REPO_NAME}/sdk/build/outputs/aar/sdk-release.aar" \
    cardboard/cardboard-sdk.aar

cp \
    "${CARB_REPO_NAME}/sdk/include/cardboard.h" \
    cardboard/cardboard.h


# Verify Cardboard output
test -f cardboard/cardboard-sdk.aar
test -f cardboard/cardboard.h

echo "============================================"
echo "Cardboard SDK prepared successfully:"
ls -lh cardboard/cardboard-sdk.aar
ls -lh cardboard/cardboard.h
echo "============================================"

rm -rf "${CARB_REPO_NAME}"


# ============================================================
# Legacy Google VR SDK
# ============================================================

rm -rf "gvr-android-sdk-1.200"

if [ "$nogvr" != true ]; then

    echo "Preparing legacy Google VR SDK..."

    rm -f download.zip

    curl \
        --fail \
        --location \
        --show-error \
        --silent \
        "https://github.com/googlevr/gvr-android-sdk/releases/download/v1.200/gvr-android-sdk-1.200.zip" \
        --output download.zip

    unzip -tq download.zip
    unzip download.zip

    rm -f download.zip

else

    echo "noGvr build selected; skipping legacy Google VR SDK."

fi


echo "============================================"
echo "PhoneVR dependency preparation completed."
echo "nogvr=${nogvr}"
echo "============================================"
