#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
destination="${KITH_SIMULATOR_DESTINATION:-}"
derived_data="${KITH_DERIVED_DATA:-/private/tmp/kith-ios-derived}"

cd "$project_root"
xcodegen generate

if [[ -z "$destination" ]]; then
  simulator_id="$(
    xcrun simctl list devices available -j | python3 -c '
import json
import sys

devices = json.load(sys.stdin).get("devices", {})
candidates = []
for runtime, entries in devices.items():
    for device in entries:
        if device.get("isAvailable") and device.get("name") == "iPhone 17 Pro":
            candidates.append((runtime != "com.apple.CoreSimulator.SimRuntime.iOS-26-2", runtime, device["udid"]))
if candidates:
    print(sorted(candidates)[0][2])
'
  )"

  if [[ -z "$simulator_id" ]]; then
    # GitHub's macOS image includes the iOS 26.2 runtime but may not pre-create
    # any simulator devices for the selected Xcode. Create the exact device the
    # project tests against instead of weakening CI to a build-only check.
    simulator_id="$(xcrun simctl create \
      "Kith CI iPhone 17 Pro" \
      "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro" \
      "com.apple.CoreSimulator.SimRuntime.iOS-26-2")"
  fi
  destination="platform=iOS Simulator,id=${simulator_id}"
fi

xcodebuild \
  -project Kith.xcodeproj \
  -scheme Kith \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  test
xcodebuild \
  -project Kith.xcodeproj \
  -scheme Kith \
  -configuration Release \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build
