#!/usr/bin/env bash
set -euo pipefail

# 配置
DEBUG="${DEBUG:-false}"
BUILD_VP9="${BUILD_VP9:-false}"
BRANCH="${BRANCH:-master}"
IOS="${IOS:-false}"

# 输出目录（相对于脚本所在目录）
OUTPUT_DIR="out"
COMMON_GN_ARGS="is_debug=${DEBUG} \
rtc_libvpx_build_vp9=${BUILD_VP9} \
is_component_build=false \
rtc_include_tests=false \
rtc_enable_objc_symbol_export=true \
enable_stripping=true \
enable_dsyms=false \
use_lld=true \
rtc_ios_use_opengl_rendering=true"

build_ios() {
    local arch="$1"
    local env="$2"
    local gen_dir="${OUTPUT_DIR}/ios-${arch}-${env}"
    local gn_args="${COMMON_GN_ARGS} \
target_cpu=\"${arch}\" \
target_os=\"ios\" \
target_environment=\"${env}\" \
ios_deployment_target=\"14.0\" \
ios_enable_code_signing=false"

    echo "➤ GN gen for ${arch}/${env} → ${gen_dir}"
    gn gen "${gen_dir}" --args="${gn_args}"
    echo "➤ ninja build webrtc (static) for ${arch}/${env}"
    ninja -C "${gen_dir}" webrtc
}

# 清理旧产物
rm -rf "${OUTPUT_DIR}"

# 只做真机 arm64
if [ "${IOS}" = "true" ]; then
    build_ios arm64 device
else
    echo "请设置 IOS=true 以编译 iOS 真机版本"
    exit 1
fi

# 拷贝静态库
SRC_LIB="${OUTPUT_DIR}/ios-arm64-device/obj/sdk/libwebrtc.a"
DST_LIB="${OUTPUT_DIR}/libwebrtc.a"
if [ ! -f "${SRC_LIB}" ]; then
    echo "✖ 找不到静态库：${SRC_LIB}"
    exit 1
fi

mkdir -p "$(dirname "${DST_LIB}")"
cp "${SRC_LIB}" "${DST_LIB}"
echo "✔ 输出静态库到：${DST_LIB}"