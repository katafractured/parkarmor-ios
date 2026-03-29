#!/bin/sh
# ci_post_clone.sh — runs after Xcode Cloud clones the repo.
#
# Sets CURRENT_PROJECT_VERSION to the Xcode Cloud build number so every
# TestFlight upload has a unique build number. Without this, Apple rejects
# uploads that reuse an existing build number and the build never appears.
#
# Xcode Cloud runs this script from the ci_scripts/ subdirectory, so we
# must cd to the repo root (CI_PRIMARY_REPOSITORY_PATH) before touching
# the project file. agvtool exit code 3 means it can't find the project.

set -e

# Only run inside Xcode Cloud (CI_BUILD_NUMBER is set by the system).
if [ -z "$CI_BUILD_NUMBER" ]; then
    echo "Not running in Xcode Cloud — skipping build number update."
    exit 0
fi

echo "Setting build number to $CI_BUILD_NUMBER"

# Move to the repo root where the .xcodeproj lives.
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Directly patch every CURRENT_PROJECT_VERSION entry in the project file.
# This avoids relying on agvtool's apple-generic versioning requirement.
find . -name "project.pbxproj" -exec \
    sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*/CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER/g" {} +

echo "Build number updated to $CI_BUILD_NUMBER in project.pbxproj"
