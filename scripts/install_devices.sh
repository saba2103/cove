#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "=========================================="
echo "  Cove Multi-Device Wireless Installer    "
echo "=========================================="

BUILD_TYPE="${1:---release}"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ "$BUILD_TYPE" == "--debug" ]; then
  APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
fi

echo "Building APK ($BUILD_TYPE)..."
flutter build apk $BUILD_TYPE

if [ ! -f "$APK_PATH" ]; then
  echo "Error: APK not found at $APK_PATH"
  exit 1
fi

echo ""
echo "Scanning for connected ADB devices..."
RAW_DEVICES=()
while IFS= read -r line; do
  [ -z "$line" ] && continue
  dev=$(echo "$line" | sed 's/[[:space:]]*device$//')
  # Test if device is actually reachable
  if adb -s "$dev" shell echo "ping" >/dev/null 2>&1; then
    # Filter duplicate devices by product model if already added
    model=$(adb -s "$dev" shell getprop ro.product.model 2>/dev/null | tr -d '\r\n')
    already_added=0
    for seen_model in "${SEEN_MODELS[@]}"; do
      if [ "$seen_model" == "$model" ] && [ -n "$model" ]; then
        already_added=1
        break
      fi
    done
    if [ $already_added -eq 0 ]; then
      RAW_DEVICES+=("$dev")
      SEEN_MODELS+=("$model")
    fi
  fi
done < <(adb devices | grep -E '\tdevice$')

DEVICES=("${RAW_DEVICES[@]}")

if [ ${#DEVICES[@]} -eq 0 ]; then
  echo "Error: No connected Android devices found via ADB."
  echo "Make sure Wireless Debugging is active on both devices."
  exit 1
fi

echo "Found ${#DEVICES[@]} device(s):"
for dev in "${DEVICES[@]}"; do
  MODEL=$(adb -s "$dev" shell getprop ro.product.model 2>/dev/null || echo "Unknown")
  echo "  • $dev ($MODEL)"
done

echo ""
echo "Installing to all devices in parallel..."
PIDS=()
for dev in "${DEVICES[@]}"; do
  (
    MODEL=$(adb -s "$dev" shell getprop ro.product.model 2>/dev/null || echo "$dev")
    echo "[$MODEL] Installing $APK_PATH..."
    if adb -s "$dev" install -r "$APK_PATH"; then
      echo "[$MODEL] ✓ Installation successful!"
    else
      echo "[$MODEL] ✗ Installation failed."
    fi
  ) &
  PIDS+=($!)
done

# Wait for all background installs
FAIL=0
for pid in "${PIDS[@]}"; do
  wait $pid || FAIL=1
done

if [ $FAIL -eq 0 ]; then
  echo ""
  echo "✓ All devices successfully updated with latest Cove build!"
else
  echo ""
  echo "⚠ Some installations encountered issues. Check logs above."
fi
