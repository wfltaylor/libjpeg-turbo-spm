#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

PRODUCT_NAME="CLibJPEGTurbo"
ZIP_NAME="${PRODUCT_NAME}.xcframework.zip"
BUILD_DIR="./build"

command -v gh > /dev/null || { echo "gh not found (brew install gh)"; exit 1; }

VERSION="${1:-$(git -C libjpeg-turbo describe --tags --exact-match 2> /dev/null || true)}"
[ -n "$VERSION" ] || { echo "The submodule is not at a tag; pass a version"; exit 1; }

if [ -n "$(git status --porcelain)" ]; then
    echo "Commit any changes before creating a release"
    exit 1
fi
if git rev-parse -q --verify "refs/tags/${VERSION}" > /dev/null; then
    echo "Tag ${VERSION} already exists"
    exit 1
fi

REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
ASSET_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ZIP_NAME}"

./build-xcframework.sh

echo "Creating release ${VERSION}"

(cd "$BUILD_DIR" && rm -f "$ZIP_NAME" && zip -qry "$ZIP_NAME" "${PRODUCT_NAME}.xcframework")
CHECKSUM="$(swift package compute-checksum "${BUILD_DIR}/${ZIP_NAME}")"

sed -i '' "s|^let releaseURL = \".*\"|let releaseURL = \"${ASSET_URL}\"|" Package.swift
sed -i '' "s|^let releaseChecksum = \".*\"|let releaseChecksum = \"${CHECKSUM}\"|" Package.swift

git add Package.swift
git commit -m "Release ${VERSION}"
git tag "$VERSION"
git push
git push origin "$VERSION"

gh release create "$VERSION" "${BUILD_DIR}/${ZIP_NAME}" --verify-tag --title "$VERSION" \
    --notes "libjpeg-turbo $(cat "${BUILD_DIR}/${PRODUCT_NAME}.xcframework/LIBJPEG_TURBO_VERSION") as ${PRODUCT_NAME}.xcframework."

echo "Released ${VERSION}: ${ASSET_URL}"
