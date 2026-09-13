#!/bin/bash
# Runs the production scheduling and timer models without requiring an iOS runtime.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
check_dir="$(mktemp -d /tmp/tasq-model-checks.XXXXXX)"
trap 'rm -rf "$check_dir"' EXIT
mkdir -p "$check_dir/Sources/Tasq" "$check_dir/Tests/TasqTests"
cp "$repo_dir/Tasq/ChartModels.swift" "$repo_dir/Tasq/DynamicSchedulePlanner.swift" "$repo_dir/Tasq/RoutineSession.swift" "$repo_dir/Tasq/FriendGroupModels.swift" "$check_dir/Sources/Tasq/"
cp "$repo_dir/TasqTests/TasqTests.swift" "$repo_dir/TasqTests/FriendGroupTests.swift" "$check_dir/Tests/TasqTests/"
cat > "$check_dir/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "TasqModelChecks", platforms: [.macOS(.v14)], targets: [
    .target(name: "Tasq"),
    .testTarget(name: "TasqTests", dependencies: ["Tasq"])
], swiftLanguageModes: [.v5])
PACKAGE
xcrun swift test --package-path "$check_dir"
