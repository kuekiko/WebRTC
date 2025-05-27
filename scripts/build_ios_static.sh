#!/usr/bin/env bash
set -euxo pipefail

# —— 配置 —— 
DEBUG="${DEBUG:-false}"
BUILD_VP9="${BUILD_VP9:-false}"
BRANCH="${BRANCH:-master}"
IOS="${IOS:-false}"

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

# —— 确保 depot_tools 可用 —— 
if [ ! -d depot_tools ]; then
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
fi
export PATH="$(pwd)/depot_tools:$PATH"

# —— 只做 arm64 真机 —— 
if [ "${IOS}" != "true" ]; then
  echo "请设置 IOS=true 后再运行此脚本"
  exit 1
fi

# —— 进入工作目录 —— 
# 假设脚本位于 <repo>/scripts 下
REPO_ROOT="$(cd "$(dirname "$0")"/.. && pwd)"
cd "${REPO_ROOT}"

# —— 获取源码 —— 
if [ ! -d src/.git ]; then
  fetch --nohooks webrtc_ios
fi
cd src
git fetch --all
git checkout "${BRANCH}"
cd ..

# —— 同步依赖 —— 
gclient sync --with_branch_heads --with_tags

# —— 构建 arm64-device —— 
build_ios() {
  local arch="$1" env="$2"
  local gen_dir="${OUTPUT_DIR}/ios-${arch}-${env}"
  mkdir -p "${gen_dir}"

  gn gen "${gen_dir}" --args="${COMMON_GN_ARGS} \
target_cpu=\"${arch}\" \
target_os=\"ios\" \
target_environment=\"${env}\" \
ios_deployment_target=\"14.0\" \
ios_enable_code_signing=false"

  ninja -C "${gen_dir}" webrtc
}

mkdir -p "${OUTPUT_DIR}"
build_ios arm64 device

# —— 调试输出 obj 目录树 —— 
OBJ_DIR="${OUTPUT_DIR}/ios-arm64-device/obj"
echo
echo "=== ${OBJ_DIR} 目录树 ==="
find "${OBJ_DIR}" -maxdepth 4 | sed 's|^|    |'
echo

# —— 查找并复制 libwebrtc.a —— 
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