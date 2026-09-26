#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

PRODUCT_NAME="CLibJPEGTurbo"
IOS_MIN="15.0"
MACOS_MIN="13.0"

SOURCE_DIR="${PWD}/libjpeg-turbo"
BUILD_DIR="${PWD}/build"
OUTPUT_DIR="${BUILD_DIR}/output"
XCFRAMEWORK="${BUILD_DIR}/${PRODUCT_NAME}.xcframework"

CMAKE="${CMAKE:-cmake}"
CLANG="$(xcrun -f clang)"
JOBS="$(sysctl -n hw.ncpu)"

export ZERO_AR_DATE=1

command -v "$CMAKE" > /dev/null || { echo "cmake not found (brew install cmake, or set CMAKE)"; exit 1; }
[ -f "${SOURCE_DIR}/CMakeLists.txt" ] || git submodule update --init libjpeg-turbo

VERSION="$(git -C "$SOURCE_DIR" describe --tags --exact-match 2> /dev/null || git -C "$SOURCE_DIR" rev-parse --short HEAD)"
echo "libjpeg-turbo ${VERSION}"

rm -rf "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

build_slice () {
    local name="$1" sdk="$2" arch="$3" processor="$4" simd="$5" minflag="$6"
    local dir="${BUILD_DIR}/${name}"
    local system="iOS"
    [ "$sdk" = "macosx" ] && system="Darwin"

    echo "Building ${name}..."
    mkdir -p "$dir"
    
    cat > "${dir}/toolchain.cmake" <<EOF
set(CMAKE_SYSTEM_NAME ${system})
set(CMAKE_SYSTEM_PROCESSOR ${processor})
set(CMAKE_C_COMPILER ${CLANG})
EOF
    "$CMAKE" -S "$SOURCE_DIR" -B "$dir" -G "Unix Makefiles" \
        -DCMAKE_TOOLCHAIN_FILE="${dir}/toolchain.cmake" \
        -DCMAKE_OSX_SYSROOT="$(xcrun --sdk "$sdk" --show-sdk-path)" \
        -DCMAKE_OSX_ARCHITECTURES="$arch" \
        -DCMAKE_C_FLAGS="$minflag" \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_SHARED=OFF -DENABLE_STATIC=ON \
        -DWITH_TURBOJPEG=OFF \
        -DWITH_SIMD="$simd" -DREQUIRE_SIMD="$simd" > "${dir}.log"
    "$CMAKE" --build "$dir" --target jpeg-static -j "$JOBS" >> "${dir}.log"
}

build_slice ios-arm64 iphoneos arm64 aarch64 ON "-miphoneos-version-min=${IOS_MIN}"
build_slice sim-arm64 iphonesimulator arm64 aarch64 ON "-mios-simulator-version-min=${IOS_MIN}"
build_slice sim-x86_64 iphonesimulator x86_64 x86_64 OFF "-mios-simulator-version-min=${IOS_MIN}"
build_slice macos-arm64 macosx arm64 aarch64 ON "-mmacosx-version-min=${MACOS_MIN}"
build_slice macos-x86_64 macosx x86_64 x86_64 OFF "-mmacosx-version-min=${MACOS_MIN}"

package_slice () {
    local name="$1" config_dir="$2"
    shift 2
    local out="${OUTPUT_DIR}/${name}"
    local headers="${out}/Headers/${PRODUCT_NAME}"
    mkdir -p "$headers"

    local libraries=()
    for slice in "$@"; do libraries+=("${BUILD_DIR}/${slice}/libjpeg.a"); done
    lipo -create "${libraries[@]}" -output "${out}/libjpeg.a"

    cp "${SOURCE_DIR}/src/jpeglib.h" "${SOURCE_DIR}/src/jmorecfg.h" "${SOURCE_DIR}/src/jerror.h" "$headers/"
    cp "${BUILD_DIR}/${config_dir}/jconfig.h" "$headers/"
    cp module/* "$headers/"
}

package_slice ios ios-arm64 ios-arm64
package_slice simulator sim-arm64 sim-arm64 sim-x86_64
package_slice macos macos-arm64 macos-arm64 macos-x86_64

xcodebuild -create-xcframework \
    -library "${OUTPUT_DIR}/ios/libjpeg.a" -headers "${OUTPUT_DIR}/ios/Headers" \
    -library "${OUTPUT_DIR}/simulator/libjpeg.a" -headers "${OUTPUT_DIR}/simulator/Headers" \
    -library "${OUTPUT_DIR}/macos/libjpeg.a" -headers "${OUTPUT_DIR}/macos/Headers" \
    -output "$XCFRAMEWORK" > /dev/null

cp "${SOURCE_DIR}/LICENSE.md" "${SOURCE_DIR}/README.ijg" "$XCFRAMEWORK/"
echo "$VERSION" > "${XCFRAMEWORK}/LIBJPEG_TURBO_VERSION"

echo "Wrote ${XCFRAMEWORK}"
