#!/bin/sh

## WebRTC static library build script for iOS arm64 only
## Outputs: static libwebrtc.a (with ObjC wrappers)

# Configs
DEBUG="${DEBUG:-false}"
BUILD_VP9="${BUILD_VP9:-false}"
BRANCH="${BRANCH:-master}"
IOS="${IOS:-false}"

OUTPUT_DIR="./out"
PLISTBUDDY_EXEC="/usr/libexec/PlistBuddy"
COMMON_GN_ARGS="is_debug=${DEBUG} rtc_libvpx_build_vp9=${BUILD_VP9} is_component_build=false rtc_include_tests=false rtc_enable_objc_symbol_export=true enable_stripping=true enable_dsyms=false use_lld=true rtc_ios_use_opengl_rendering=true"

build_iOS() {
    local arch=$1
    local environment=$2
    local gen_dir="${OUTPUT_DIR}/ios-${arch}-${environment}"
    local gen_args="${COMMON_GN_ARGS} target_cpu=\"${arch}\" target_os=\"ios\" target_environment=\"${environment}\" ios_deployment_target=\"14.0\" ios_enable_code_signing=false"

    # generate build files
    gn gen "${gen_dir}" --args="${gen_args}"
    # record args
    gn args --list ${gen_dir} > ${gen_dir}/gn-args.txt

    # build static ObjC framework (includes ObjC wrappers)
    ninja -C "${gen_dir}" framework_objc || exit 1

    # extract the static archive
    mkdir -p "${OUTPUT_DIR}"
    cp "${gen_dir}/obj/libwebrtc.a" "${OUTPUT_DIR}/libwebrtc.a"
}

# Step 1: setup depot_tools
if [ ! -d depot_tools ]; then
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
else
    (cd depot_tools && git pull origin main)
fi
export PATH=$(pwd)/depot_tools:$PATH

# Step 2: fetch and sync WebRTC code
if [ ! -d src ]; then
    fetch --nohooks webrtc_ios
fi
cd src
git fetch --all
git checkout $BRANCH
cd ..
gclient sync --with_branch_heads --with_tags
cd src

# Step 3: build for iOS arm64 device only
rm -rf $OUTPUT_DIR
if [ "$IOS" = true ]; then
    build_iOS "arm64" "device"
fi

# Final: list outputs
ls -lh "${OUTPUT_DIR}/libwebrtc.a"