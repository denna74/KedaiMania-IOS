#!/bin/bash
set -euo pipefail

GODOT_TAG="4.6-stable"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
export PATH="$PATH:/opt/homebrew/bin"
UNITY_ADS_VERSION="${UNITY_ADS_VERSION:-4.18.1}"
VENDOR_DIR="$SCRIPT_DIR/vendor"
mkdir -p "$VENDOR_DIR"

if [ ! -d "$VENDOR_DIR/UnityAds.xcframework" ]; then
    URL="${UNITY_ADS_SDK_URL:-https://github.com/Unity-Technologies/unity-ads-ios/releases/download/${UNITY_ADS_VERSION}/UnityAds.zip}"
    TMP="$(mktemp -d)"
    curl -L --fail -o "$TMP/unityads.zip" "$URL"
    unzip -q "$TMP/unityads.zip" -d "$TMP"
    test -d "$TMP/UnityAds.xcframework"
    cp -R "$TMP/UnityAds.xcframework" "$VENDOR_DIR/UnityAds.xcframework"
    rm -rf "$TMP"
fi

PLUGIN_NAME="godot_unity_ads"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
git clone --recursive --depth 1 https://github.com/godotengine/godot-ios-plugins.git "$WORK/godot-ios-plugins"
cd "$WORK/godot-ios-plugins"
cd godot
git fetch --depth 1 origin tag "$GODOT_TAG"
git checkout "$GODOT_TAG"
scons platform=ios target=editor -j2
cd ..

mkdir -p "plugins/$PLUGIN_NAME"
cp "$SCRIPT_DIR/src/GodotUnityAds.h" "$SCRIPT_DIR/src/GodotUnityAds.mm" "plugins/$PLUGIN_NAME/"
python3 - "$PLUGIN_NAME" "$SCRIPT_DIR" <<'PYEOF'
import sys
name, script_dir = sys.argv[1], sys.argv[2]
with open("SConstruct") as f:
    text = f.read()
marker = "['', 'apn', 'arkit', 'camera', 'icloud', 'gamecenter', 'inappstore', 'photo_picker']"
text = text.replace(marker, "['', 'apn', 'arkit', 'camera', 'icloud', 'gamecenter', 'inappstore', 'photo_picker', '%s']" % name)
framework_parent = script_dir + "/vendor/UnityAds.xcframework/ios-arm64"
fw_marker = "env.Prepend(CXXFLAGS=['-DVULKAN_ENABLED', '-std=gnu++17'])"
text = text.replace(
    fw_marker,
    fw_marker
    + "\n    env.Append(CCFLAGS=['-F', '%s'])" % framework_parent
    + "\n    env.Append(LINKFLAGS=['-F', '%s', '-framework', 'UnityAds'])" % framework_parent
)
with open("SConstruct", "w") as f:
    f.write(text)
PYEOF

scons use_llvm=yes target=release arch=arm64 plugin=$PLUGIN_NAME version=4.0
scons use_llvm=yes target=release arch=arm64 simulator=yes plugin=$PLUGIN_NAME version=4.0
xcodebuild -create-xcframework \
    -library "./bin/lib$PLUGIN_NAME.arm64-ios.release.a" \
    -library "./bin/lib$PLUGIN_NAME.arm64-simulator.release.a" \
    -output "$ROOT_DIR/ios/plugins/unity-ads/bin/unity-ads-bridge.xcframework"
