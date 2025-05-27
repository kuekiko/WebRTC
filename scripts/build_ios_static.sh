#!/usr/bin/env bash
set -euxo pipefail

# —— 配置 —— 
DEBUG="${DEBUG:-false}"
BUILD_VP9="${BUILD_VP9:-false}"
BRANCH="${BRANCH:-master}"
IOS="${IOS:-false}"

# 构建输出根目录（位于 src/ 下）
OUTPUT_DIR="src/out"
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
  local arch="$1" local env="$2"
  local gen_dir="${OUTPUT_DIR}/ios-${arch}-${env}"
  local gn_args="${COMMON_GN_ARGS} \
target_cpu=\"${arch}\" \
target_os=\"ios\" \
target_environment=\"${env}\" \
ios_deployment_target=\"14.0\" \
ios_enable_code_signing=false"

  echo "▶ gn gen in ${gen_dir}"
  gn gen "${gen_dir}" --args="${gn_args}"

  echo "▶ ninja build webrtc (static) in ${gen_dir}"
  ninja -C "${gen_dir}" webrtc
}

# —— 只做 arm64 真机 —— 
if [ "${IOS}" != "true" ]; then
  echo "请设置 IOS=true 后再运行此脚本"
  exit 1
fi

# 保证输出目录存在
mkdir -p "${OUTPUT_DIR}"

# 进入 src 目录，检出分支并同步 deps
if [ ! -d src/.git ]; then
  fetch --nohooks webrtc_ios
fi
cd src
git fetch --all
git checkout "${BRANCH}"
cd ..

# 同步依赖
gclient sync --with_branch_heads --with_tags

# 真机 arm64
build_ios arm64 device

# —— 打印 obj 目录树，帮助排查 —— 
OBJ_DIR="${OUTPUT_DIR}/ios-arm64-device/obj"
echo
echo "=== ${OBJ_DIR} 目录树 ==="
find "${OBJ_DIR}" -maxdepth 4 | sed 's|^|    |'
echo

# —— 自动找 libwebrtc.a 并复制到 src/out/libwebrtc.a —— 
echo "=== 查找 libwebrtc*.a ==="
LIB_PATH=$(find "${OBJ_DIR}" -type f -name "libwebrtc*.a" | head -n1)
if [ -z "${LIB_PATH}" ]; then
  echo "✖ 没有找到任何 libwebrtc.a"
  exit 1
fi

DEST_LIB="${OUTPUT_DIR}/libwebrtc.a"
cp "${LIB_PATH}" "${DEST_LIB}"
echo "✔ 复制完成:"
echo "    ${LIB_PATH}"
echo "→  ${DEST_LIB}"