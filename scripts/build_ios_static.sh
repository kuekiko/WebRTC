#!/usr/bin/env bash
set -euxo pipefail

# —— 配置 —— 
DEBUG="${DEBUG:-false}"
BUILD_VP9="${BUILD_VP9:-false}"
BRANCH="${BRANCH:-master}"
IOS="${IOS:-false}"

# 输出目录
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
  local arch="$1" env="$2"
  local gen_dir="${OUTPUT_DIR}/ios-${arch}-${env}"
  local gn_args="${COMMON_GN_ARGS} \
target_cpu=\"${arch}\" \
target_os=\"ios\" \
target_environment=\"${env}\" \
ios_deployment_target=\"14.0\" \
ios_enable_code_signing=false"

  echo "➤ [GN] gen → ${gen_dir}"
  gn gen "${gen_dir}" --args="${gn_args}"
  echo "➤ [ninja] build webrtc (static) → ${gen_dir}"
  ninja -C "${gen_dir}" webrtc
}

# —— 清理旧输出 —— 
rm -rf "${OUTPUT_DIR}"

# —— 只做 arm64 真机 —— 
if [ "${IOS}" = "true" ]; then
  build_ios arm64 device
else
  echo "请设置 IOS=true 后再运行此脚本"
  exit 1
fi

GEN_DIR="${OUTPUT_DIR}/ios-arm64-device"
OBJ_DIR="${GEN_DIR}/obj"

echo
echo "=== Build 完成，列出 ${OBJ_DIR} 结构 ==="
find "${OBJ_DIR}" -maxdepth 4 | sed 's|^|    |'
echo

# —— 自动定位 libwebrtc.a —— 
echo "=== 在 ${OBJ_DIR} 中查找 libwebrtc.a ==="
LIB_PATHS=$(find "${OBJ_DIR}" -type f -name "libwebrtc*.a" || true)
if [ -z "${LIB_PATHS}" ]; then
  echo "✖ 错误：没有找到任何 libwebrtc.a"
  exit 1
fi
echo "找到以下静态库："
echo "${LIB_PATHS}" | sed 's|^|    |'

# 取第一条
SRC_LIB=$(echo "${LIB_PATHS}" | head -n1)
DST_LIB="${OUTPUT_DIR}/libwebrtc.a"
mkdir -p "$(dirname "${DST_LIB}")"
cp "${SRC_LIB}" "${DST_LIB}"

echo "✔ 已复制："
echo "    ${SRC_LIB}"
echo "  → ${DST_LIB}"