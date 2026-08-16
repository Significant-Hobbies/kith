#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
destination="${KITH_SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4}"
derived_data="${KITH_DERIVED_DATA:-/private/tmp/kith-ios-derived}"

cd "$project_root"
xcodegen generate
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
