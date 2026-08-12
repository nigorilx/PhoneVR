#!/usr/bin/env bash

set -euxo pipefail

# ============================================================
# PhoneVR dependency preparation
#
# Modified for current GitHub Actions:
# - Avoid ALVR "prepare-deps --platform android" because it
#   downloads obsolete OpenXR vendor loaders (Lynx/YVR/etc.).
# - Prepare only the tools required by PhoneVR's ALVR client_core.
# - Build the current Cardboard SDK.
# - Keep legacy GVR support when the script is called without
#   the "nogvr" argument, because the existing CI still builds it.
# ============================================================

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
#
# PhoneVR uses ALVR's client_core native library.
# We deliberately DO NOT call:
#
#     cargo xtask prepare-deps --platform android
#
# because that also downloads vendor OpenXR loaders such as
# Lynx, whose old download URL is currently broken.
# ============================================================

pushd ALVR

# Reproduce the useful submodule part of ALVR prepare-deps
# without downloading the OpenXR loaders.
git submodule update --init --recursive

# Required for ALVR Android client_core build.
cargo install cargo-ndk cbindgen

popd


# ============================================================
# Prepare Cardboard SDK
# ============================================================

rm -rf cardboard

CARB_REPO_NAME="cardboard-master"

rm -rf "${CARB_REPO_NAME}"
rm -f download.zip


# ============================================================
# Download Cardboard SDK source
# ============================================================

curl \
    --fail \
    --location \
    --show-error \
    --silent \
    "https://github.com/nift4/cardboard/archive/refs/heads/master.zip" \
    --output download.zip

# Make sure GitHub actually returned a valid ZIP file.
unzip -tq download.zip

unzip download.zip
rm -f download.zip


# ============================================================
# Build Cardboard SDK
# ============================================================

pushd "${CARB_REPO_NAME}"

chmod +x ./gradlew

./gradlew sdk:assembleRelease -Parm64-v8a

popd


# ============================================================
# Copy Cardboard build outputs used by PhoneVR
# ============================================================

mkdir -p cardboard

mv \
    "${CARB_REPO_NAME}/sdk/build/outputs/aar/sdk-release.aar" \
    cardboard/cardboard-sdk.aar

cp \
    "${CARB_REPO_NAME}/sdk/include/cardboard.h" \
    cardboard/cardboard.h


# ============================================================
# Verify Cardboard output
#
# If Cardboard fails to build in the future, stop HERE instead
# of allowing PhoneVR Gradle to fail later with:
#
# "cardboard-sdk.aar does not exist"
# ============================================================

test -f cardboard/cardboard-sdk.aar
test -f cardboard/cardboard.h

echo "============================================"
echo "Cardboard SDK prepared successfully:"
ls -lh cardboard/cardboard-sdk.aar
ls -lh cardboard/cardboard.h
echo "============================================"


# Cardboard source tree is no longer needed.
rm -rf "${CARB_REPO_NAME}"


# ============================================================
# Legacy Google VR SDK
#
# The current CI calls this script twice:
#
#   prepare-alvr-deps.sh nogvr
#   prepare-alvr-deps.sh
#
# The second run is used for the old GVR flavor, so preserve
# that behavior for now.
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
