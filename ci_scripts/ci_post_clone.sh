#!/bin/sh
# ci_post_clone.sh — runs after Xcode Cloud clones the repo.
#
# Sets CURRENT_PROJECT_VERSION to the Xcode Cloud build number so every
# TestFlight upload has a unique build number. Without this, Apple rejects
# uploads that reuse an existing build number and the build never appears.

set -e

# Only run inside Xcode Cloud (CI_BUILD_NUMBER is set by the system).
if [ -z "$CI_BUILD_NUMBER" ]; then
    echo "Not running in Xcode Cloud — skipping build number update."
    exit 0
fi

echo "Setting build number to $CI_BUILD_NUMBER"

# agvtool updates CURRENT_PROJECT_VERSION in every target in the project.
xcrun agvtool new-version -all "$CI_BUILD_NUMBER"

echo "Build number updated to $CI_BUILD_NUMBER"
