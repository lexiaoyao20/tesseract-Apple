#!/usr/bin/env bash

###############################################################################
# Tesseract macOS Apple Silicon One-Key Build Script
#
# 目标：
#   - 在 macOS 11.0+ (Big Sur) 上，为 Apple Silicon (arm64) 构建
#     可供 C 语言直接调用的 Tesseract OCR 静态 / 动态库。
#   - 自动下载并构建核心依赖：zlib、libpng、libjpeg-turbo、libtiff、Leptonica。
#   - 输出统一的安装目录，包含：
#       - lib/libtesseract.a       (静态库)
#       - lib/libtesseract_all.a   (打包所有依赖的静态库，方便 C 程序直接链接)
#       - include/                 (包含 tesseract 与 leptonica 等头文件)
#
# 使用：
#   1) 赋予执行权限并运行：
#        chmod +x build.sh
#        ./build.sh
#   2) 构建完成后，库与头文件默认输出到：
#        ./tesseract-macos-arm64
#   3) 简单 C 项目链接示例：
#        export TESS_ROOT="$(pwd)/tesseract-macos-arm64"
#        clang -std=c11 test.c \
#          -I"$TESS_ROOT/include" \
#          -L"$TESS_ROOT/lib" \
#          -ltesseract_all \
#          -framework CoreFoundation \
#          -framework CoreGraphics \
#          -framework ImageIO \
#          -framework Accelerate
#
###############################################################################

set -euo pipefail

#######################################
# 彩色输出
#######################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
print_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_step()  { echo -e "${PURPLE}[STEP]${NC}  $1"; }
print_head()  { echo -e "${BLUE}[BUILD]${NC} $1"; }

#######################################
# 配置参数（可根据需要修改）
#######################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_ROOT="${SCRIPT_DIR}/build-macos-arm64"
BUILD_ROOT_IOS="${SCRIPT_DIR}/build-ios"

# 将下载目录独立出来，避免清理构建目录时重复下载
DOWNLOADS_DIR="${SCRIPT_DIR}/downloads"

INSTALL_PREFIX="${SCRIPT_DIR}/tesseract-macos-arm64"
INSTALL_PREFIX_MACOS="${INSTALL_PREFIX}"
INSTALL_PREFIX_IOS_DEVICE="${SCRIPT_DIR}/tesseract-ios-arm64"
INSTALL_PREFIX_IOS_SIMULATOR="${SCRIPT_DIR}/tesseract-ios-simulator"

# 目标平台配置
MACOS_MIN_VERSION="${MACOS_MIN_VERSION:-11.0}"   # 最低系统版本
ARCH="${ARCH:-arm64}"                            # 仅 Apple Silicon
BUILD_TYPE="${BUILD_TYPE:-Release}"

# iOS 目标平台配置
IOS_MIN_VERSION="${IOS_MIN_VERSION:-13.0}"       # 最低 iOS 版本
IOS_ARCH_DEVICE="${IOS_ARCH_DEVICE:-arm64}"      # iOS 真机架构
IOS_ARCH_SIMULATOR="${IOS_ARCH_SIMULATOR:-arm64}" # iOS 模拟器架构
# 是否同时构建 iOS 版本（1=构建，0=仅构建 macOS）
ENABLE_IOS="${ENABLE_IOS:-1}"
# 是否保留中间构建产物（build-* 和 tesseract-ios-*），默认 0=清理，仅保留最终结果
KEEP_INTERMEDIATE="${KEEP_INTERMEDIATE:-0}"

# 版本选择（均为当前稳定且兼容的版本）
TESSERACT_VERSION="${TESSERACT_VERSION:-5.5.1}"
LEPTONICA_VERSION="${LEPTONICA_VERSION:-1.84.1}"
ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}"
LIBPNG_VERSION="${LIBPNG_VERSION:-1.6.40}"
LIBTIFF_VERSION="${LIBTIFF_VERSION:-4.6.0}"
LIBJPEG_TURBO_VERSION="${LIBJPEG_TURBO_VERSION:-3.0.0}"

# 是否构建动态库：
# 本脚本仅打包静态库（.a），不再构建或保留任何 .dylib。
BUILD_SHARED_LIBS_FLAG="OFF"

#######################################
# 通用编译参数
#######################################
export MACOSX_DEPLOYMENT_TARGET="${MACOS_MIN_VERSION}"
COMMON_CFLAGS="-arch ${ARCH} -mmacosx-version-min=${MACOS_MIN_VERSION} -O3 -DNDEBUG"
COMMON_CXXFLAGS="${COMMON_CFLAGS} -std=c++17"
COMMON_LDFLAGS="-arch ${ARCH} -mmacosx-version-min=${MACOS_MIN_VERSION}"

#######################################
# 工具检测
#######################################
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

check_macos_version() {
  if [[ "$(uname)" != "Darwin" ]]; then
    print_error "本脚本仅支持在 macOS 上运行。"
    exit 1
  fi

  local ver
  ver="$(sw_vers -productVersion | cut -d. -f1-2)"
  # 简单比较：只判断主版本 >= 11
  local major="${ver%%.*}"
  if (( major < 11 )); then
    print_error "检测到系统版本为 ${ver}，本脚本要求 macOS 11.0 及以上。"
    exit 1
  fi
}

check_dependencies() {
  print_step "检查构建工具与基础依赖..."

  local missing=()

  command_exists clang || missing+=("clang (Xcode Command Line Tools)")
  command_exists cmake || missing+=("cmake")
  command_exists make || missing+=("make")
  command_exists git || missing+=("git")

  if ! command_exists curl && ! command_exists wget; then
    missing+=("curl 或 wget")
  fi

  if ((${#missing[@]} > 0)); then
    print_error "缺少以下必需工具："
    for m in "${missing[@]}"; do
      echo "  - $m"
    done
    echo ""
    echo "建议安装方式："
    echo "  xcode-select --install"
    echo "  brew install cmake git curl"
    exit 1
  fi

  print_info "构建工具检测通过。"
}

#######################################
# 下载并解压源码
#######################################
download_and_extract() {
  local url="$1"
  local archive_name="$2"
  local extract_dir="$3"
  local expected_dir_name="${4:-}"

  mkdir -p "${DOWNLOADS_DIR}"
  cd "${DOWNLOADS_DIR}"

  if [[ -d "${extract_dir}" ]]; then
    print_info "${extract_dir} 已存在，跳过下载。"
    return 0
  fi

  print_info "下载 ${archive_name} ..."
  if [[ ! -f "${archive_name}" ]]; then
    if command_exists curl; then
      curl -L --fail --progress-bar "${url}" -o "${archive_name}"
    else
      wget --progress=bar:force "${url}" -O "${archive_name}"
    fi
  fi

  print_info "解压 ${archive_name} ..."
  case "${archive_name}" in
    *.tar.gz|*.tgz)  tar -xzf "${archive_name}" ;;
    *.tar.bz2)       tar -xjf "${archive_name}" ;;
    *.tar.xz)        tar -xJf "${archive_name}" ;;
    *.zip)           unzip -q "${archive_name}" ;;
    *)
      print_error "无法识别的压缩格式: ${archive_name}"
      exit 1
      ;;
  esac

  # 如有必要，重命名目录
  if [[ -n "${expected_dir_name}" && -d "${expected_dir_name}" && "${expected_dir_name}" != "${extract_dir}" ]]; then
    mv "${expected_dir_name}" "${extract_dir}"
  elif [[ ! -d "${extract_dir}" ]]; then
    # 若解压后目录名刚好为 extract_dir，则无需处理；否则报错
    if [[ -d "${archive_name%.tar.gz}" ]]; then
      mv "${archive_name%.tar.gz}" "${extract_dir}"
    fi
  fi
}

#######################################
# 通用 CMake 构建函数（静态 / 动态）
#######################################
build_cmake_project() {
  local name="$1"
  local src_dir="$2"
  local build_dir="$3"
  local install_prefix="$4"
  local build_shared="$5"   # "ON" 或 "OFF"
  shift 5

  local kind="static"
  if [[ "${build_shared}" == "ON" ]]; then
    kind="shared"
  fi
  print_step "构建 ${name} (${kind}) (macOS) ..."

  mkdir -p "${build_dir}"
  cd "${build_dir}"

  cmake "${src_dir}" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_INSTALL_PREFIX="${install_prefix}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOS_MIN_VERSION}" \
    -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS="${build_shared}" \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS="${COMMON_CFLAGS}" \
    -DCMAKE_CXX_FLAGS="${COMMON_CXXFLAGS}" \
    -DCMAKE_EXE_LINKER_FLAGS="${COMMON_LDFLAGS}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${COMMON_LDFLAGS}" \
    -DCMAKE_PREFIX_PATH="${install_prefix}" \
    "$@"

  local cores
  cores="$(sysctl -n hw.ncpu)"
  print_info "使用 ${cores} 个 CPU 核心编译 ${name} ..."
  make -j"${cores}"
  make install
}

#######################################
# iOS 通用 CMake 构建函数（静态 / 动态）
#######################################
build_cmake_project_ios() {
  local name="$1"
  local src_dir="$2"
  local build_dir="$3"
  local install_prefix="$4"
  local sdk="$5"           # iphoneos 或 iphonesimulator
  local arch="$6"
  local min_version="$7"
  local build_shared="$8"  # "ON" 或 "OFF"
  local extra_cflags="$9"  # 额外的 CFLAGS，可为空
  shift 9

  local kind="static"
  if [[ "${build_shared}" == "ON" ]]; then
    kind="shared"
  fi
  print_step "构建 ${name} (${kind}, ${sdk}, ${arch}, iOS >= ${min_version}) ..."

  local sdk_path
  sdk_path="$(xcrun --sdk "${sdk}" --show-sdk-path)"

  local base_cflags="-arch ${arch} -mios-version-min=${min_version} -isysroot ${sdk_path} -O3 -DNDEBUG"
  local cflags="${base_cflags}"
  if [[ -n "${extra_cflags}" ]]; then
    cflags="${base_cflags} ${extra_cflags}"
  fi
  local cxxflags="${cflags} -std=c++17"
  local ldflags="-arch ${arch} -isysroot ${sdk_path}"

  mkdir -p "${build_dir}"
  cd "${build_dir}"

  cmake "${src_dir}" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_INSTALL_PREFIX="${install_prefix}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="${sdk_path}" \
    -DCMAKE_SYSTEM_PROCESSOR="${arch}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="${min_version}" \
    -DCMAKE_OSX_ARCHITECTURES="${arch}" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS="${build_shared}" \
    -DCMAKE_C_COMPILER="$(xcrun --sdk "${sdk}" --find clang)" \
    -DCMAKE_CXX_COMPILER="$(xcrun --sdk "${sdk}" --find clang++)" \
    -DCMAKE_C_FLAGS="${cflags}" \
    -DCMAKE_CXX_FLAGS="${cxxflags}" \
    -DCMAKE_EXE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_PREFIX_PATH="${install_prefix}" \
    "$@"

  local cores
  cores="$(sysctl -n hw.ncpu)"
  print_info "使用 ${cores} 个 CPU 核心编译 ${name} (${sdk}/${arch}) ..."
  make -j"${cores}"
  make install
}

#######################################
# 创建打包静态库 libtesseract_all.a
#######################################
create_unified_static_lib() {
  local output_lib="$1"
  shift
  local input_libs=("$@")

  print_step "创建打包静态库 ${output_lib} ..."

  for lib in "${input_libs[@]}"; do
    if [[ ! -f "${lib}" ]]; then
      print_error "未找到静态库: ${lib}"
      exit 1
    fi
  done

  rm -f "${output_lib}"
  
  # 关键修复：使用 libtool -static 来合并静态库，而不是 ar rcs
  if command_exists libtool; then
    libtool -static -o "${output_lib}" "${input_libs[@]}"
  else
    print_error "未找到 libtool，无法正确合并静态库。ar 命令无法在 macOS 上合并 .a 文件。"
    exit 1
  fi
  
  print_info "已生成打包静态库: ${output_lib}"
}

#######################################
# 构建依赖：zlib, libpng, libjpeg-turbo, libtiff, leptonica
#######################################
build_dependencies() {
  print_head "开始构建依赖库 (arm64, macOS >= ${MACOS_MIN_VERSION}) ..."
  mkdir -p "${BUILD_ROOT}" "${DOWNLOADS_DIR}" "${INSTALL_PREFIX}"

  # 1. zlib
  print_step "构建 zlib ${ZLIB_VERSION}"
  download_and_extract \
    "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz" \
    "zlib-${ZLIB_VERSION}.tar.gz" \
    "zlib-${ZLIB_VERSION}"

  build_cmake_project \
    "zlib" \
    "${DOWNLOADS_DIR}/zlib-${ZLIB_VERSION}" \
    "${BUILD_ROOT}/zlib-build" \
    "${INSTALL_PREFIX}" \
    "OFF" \
    -DZLIB_BUILD_EXAMPLES=OFF

  # 2. libpng
  print_step "构建 libpng ${LIBPNG_VERSION}"
  download_and_extract \
    "https://downloads.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz" \
    "libpng-${LIBPNG_VERSION}.tar.gz" \
    "libpng-${LIBPNG_VERSION}"

  # libpng 1.6.x 在现代 macOS 上仍然尝试包含过时的 <fp.h>（见 pngpriv.h），
  # 该头文件已不存在，因此这里提供一个空的 stub 头文件，并通过 -I 提前放入搜索路径。
  local PNG_FIX_DIR="${BUILD_ROOT}/libpng-fix"
  mkdir -p "${PNG_FIX_DIR}/include"
  cat > "${PNG_FIX_DIR}/include/fp.h" <<'EOF'
/* Stub header for legacy <fp.h> on modern macOS. */
#ifndef FP_H_STUB
#define FP_H_STUB
#include <math.h>
#endif
EOF
  local PNG_CFLAGS="${COMMON_CFLAGS} -I${PNG_FIX_DIR}/include"

  build_cmake_project \
    "libpng" \
    "${DOWNLOADS_DIR}/libpng-${LIBPNG_VERSION}" \
    "${BUILD_ROOT}/libpng-build" \
    "${INSTALL_PREFIX}" \
    "OFF" \
    -DPNG_SHARED=OFF \
    -DPNG_TESTS=OFF \
    "-DCMAKE_C_FLAGS=${PNG_CFLAGS}"

  # 3. libjpeg-turbo
  print_step "构建 libjpeg-turbo ${LIBJPEG_TURBO_VERSION}"
  download_and_extract \
    "https://github.com/libjpeg-turbo/libjpeg-turbo/archive/${LIBJPEG_TURBO_VERSION}.tar.gz" \
    "libjpeg-turbo-${LIBJPEG_TURBO_VERSION}.tar.gz" \
    "libjpeg-turbo-${LIBJPEG_TURBO_VERSION}"

  build_cmake_project \
    "libjpeg-turbo" \
    "${DOWNLOADS_DIR}/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}" \
    "${BUILD_ROOT}/libjpeg-turbo-build" \
    "${INSTALL_PREFIX}" \
    "OFF" \
    -DENABLE_SHARED=OFF \
    -DENABLE_STATIC=ON \
    -DWITH_TURBOJPEG=OFF

  # 4. libtiff
  print_step "构建 libtiff ${LIBTIFF_VERSION}"
  download_and_extract \
    "https://download.osgeo.org/libtiff/tiff-${LIBTIFF_VERSION}.tar.gz" \
    "tiff-${LIBTIFF_VERSION}.tar.gz" \
    "tiff-${LIBTIFF_VERSION}"

  # 关键修复：强制禁用 libtiff 的所有可选依赖 (libdeflate, zstd, lzma, webp)
  build_cmake_project \
    "libtiff" \
    "${DOWNLOADS_DIR}/tiff-${LIBTIFF_VERSION}" \
    "${BUILD_ROOT}/libtiff-build" \
    "${INSTALL_PREFIX}" \
    "OFF" \
    -Dtiff-tools=OFF \
    -Dtiff-tests=OFF \
    -Dtiff-contrib=OFF \
    -Dtiff-docs=OFF \
    -Dlibdeflate=OFF \
    -Dzstd=OFF \
    -Dlzma=OFF \
    -Dwebp=OFF \
    -Djbig=OFF

  # 5. leptonica
  print_step "构建 Leptonica ${LEPTONICA_VERSION}"
  download_and_extract \
    "https://github.com/DanBloomberg/leptonica/releases/download/${LEPTONICA_VERSION}/leptonica-${LEPTONICA_VERSION}.tar.gz" \
    "leptonica-${LEPTONICA_VERSION}.tar.gz" \
    "leptonica-${LEPTONICA_VERSION}"

  # 为 Leptonica 提供一个空的 CMath::CMath 目标，以兼容
  # libtiff 安装的 CMake 配置中对 CMath::CMath 的可选引用。
  # 这样可以避免在上层项目中强制要求 find_package(CMath)。
  local LEPT_SRC="${DOWNLOADS_DIR}/leptonica-${LEPTONICA_VERSION}"
  local LEPT_CMAKELISTS="${LEPT_SRC}/CMakeLists.txt"
  if [[ -f "${LEPT_CMAKELISTS}" ]] && ! grep -q "Tesseract macOS: stub CMath::CMath target" "${LEPT_CMAKELISTS}" >/dev/null 2>&1; then
    print_info "为 Leptonica 添加 CMath::CMath stub 目标 (macOS) ..."
    local LEPT_TMP="${LEPT_CMAKELISTS}.tmp"
    awk '
      BEGIN { inserted = 0 }
      {
        print $0
        if (!inserted && index($0, "set(CMAKE_MODULE_PATH ") == 1) {
          print ""
          print "# Tesseract macOS: stub CMath::CMath target"
          print "if(NOT TARGET CMath::CMath)"
          print "  add_library(CMath::CMath INTERFACE IMPORTED)"
          print "endif()"
          print "# End Tesseract macOS CMath stub"
          inserted = 1
        }
      }
    ' "${LEPT_CMAKELISTS}" > "${LEPT_TMP}" && mv "${LEPT_TMP}" "${LEPT_CMAKELISTS}"
  fi

  # 关键修复：显式定义宏，确保 Leptonica 在运行时不会报 "function not present"
  local LEPT_CFLAGS="${COMMON_CFLAGS} -DHAVE_LIBPNG=1 -DHAVE_LIBJPEG=1 -DHAVE_LIBTIFF=1 -DHAVE_LIBZ=1"

  build_cmake_project \
    "leptonica" \
    "${DOWNLOADS_DIR}/leptonica-${LEPTONICA_VERSION}" \
    "${BUILD_ROOT}/leptonica-build" \
    "${INSTALL_PREFIX}" \
    "OFF" \
    "-DCMAKE_C_FLAGS=${LEPT_CFLAGS}" \
    -DSTATIC=ON \
    -DSHARED=OFF \
    -DBUILD_PROG=OFF \
    -DBUILD_TESTS=OFF \
    -DENABLE_TIFF=ON \
    -DENABLE_WEBP=OFF \
    -DENABLE_OPENJPEG=OFF \
    -DENABLE_GIF=OFF \
    -DENABLE_JPEG=ON \
    -DENABLE_PNG=ON \
    -DENABLE_ZLIB=ON \
    -DCMAKE_DISABLE_FIND_PACKAGE_Deflate=ON \
    -DTIFF_LIBRARY="${INSTALL_PREFIX}/lib/libtiff.a" \
    -DTIFF_INCLUDE_DIR="${INSTALL_PREFIX}/include" \
    -DPNG_LIBRARY="${INSTALL_PREFIX}/lib/libpng.a" \
    -DPNG_PNG_INCLUDE_DIR="${INSTALL_PREFIX}/include" \
    -DJPEG_LIBRARY="${INSTALL_PREFIX}/lib/libjpeg.a" \
    -DJPEG_INCLUDE_DIR="${INSTALL_PREFIX}/include" \
    -DZLIB_LIBRARY="${INSTALL_PREFIX}/lib/libz.a" \
    -DZLIB_INCLUDE_DIR="${INSTALL_PREFIX}/include"

  # 清理 Leptonica 导出的 CMake 目标，去掉对 ZLIB::ZLIB / JPEG::JPEG / CMath::CMath
  # 这些 imported target 的依赖，避免在 Tesseract 的 CMake 配置阶段出错。
  local LEPT_TARGETS_CMAKE="${INSTALL_PREFIX}/lib/cmake/leptonica/LeptonicaTargets.cmake"
  if [[ -f "${LEPT_TARGETS_CMAKE}" ]] && ! grep -q "Tesseract macOS: cleaned INTERFACE_LINK_LIBRARIES" "${LEPT_TARGETS_CMAKE}" >/dev/null 2>&1; then
    print_info "清理 Leptonica CMake 导出的依赖目标 (macOS) ..."
    local LEPT_TARGETS_TMP="${LEPT_TARGETS_CMAKE}.tmp"
    awk '
      /INTERFACE_LINK_LIBRARIES/ {
        # 删除包含 ZLIB::ZLIB / JPEG::JPEG / CMath::CMath 的段落
        gsub(/;[^;]*ZLIB::ZLIB[^;]*/, "", $0)
        gsub(/;[^;]*JPEG::JPEG[^;]*/, "", $0)
        gsub(/;[^;]*CMath::CMath[^;]*/, "", $0)
        print $0
        next
      }
      { print $0 }
    ' "${LEPT_TARGETS_CMAKE}" > "${LEPT_TARGETS_TMP}" && mv "${LEPT_TARGETS_TMP}" "${LEPT_TARGETS_CMAKE}"
  fi

  print_info "依赖库构建完成。"
}

#######################################
# 构建 iOS 依赖：zlib, libpng, libjpeg-turbo, libtiff, leptonica
#######################################
#######################################
# 构建 iOS 依赖（单一变体）
#######################################
build_dependencies_ios_variant() {
  local sdk="$1"           # iphoneos / iphonesimulator
  local arch="$2"
  local install_prefix="$3"
  local variant_name="$4"  # 用于区分 build 目录，例如 ios-device / ios-simulator

  print_head "开始构建依赖库 (${variant_name}, ${sdk}, ${arch}, iOS >= ${IOS_MIN_VERSION}) ..."

  local build_root="${BUILD_ROOT_IOS}/${variant_name}"
  mkdir -p "${build_root}" "${DOWNLOADS_DIR}" "${install_prefix}"

  # 1. zlib
  print_step "构建 zlib ${ZLIB_VERSION} (${variant_name})"
  download_and_extract \
    "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz" \
    "zlib-${ZLIB_VERSION}.tar.gz" \
    "zlib-${ZLIB_VERSION}"

  build_cmake_project_ios \
    "zlib-${variant_name}" \
    "${DOWNLOADS_DIR}/zlib-${ZLIB_VERSION}" \
    "${build_root}/zlib-build" \
    "${install_prefix}" \
    "${sdk}" \
    "${arch}" \
    "${IOS_MIN_VERSION}" \
    "OFF" \
    "" \
    -DZLIB_BUILD_EXAMPLES=OFF

  # 2. libpng
  print_step "构建 libpng ${LIBPNG_VERSION} (${variant_name})"
  download_and_extract \
    "https://downloads.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz" \
    "libpng-${LIBPNG_VERSION}.tar.gz" \
    "libpng-${LIBPNG_VERSION}"

  # 为 iOS 平台同样提供 <fp.h> stub 头文件
  local PNG_FIX_DIR="${build_root}/libpng-fix"
  mkdir -p "${PNG_FIX_DIR}/include"
  cat > "${PNG_FIX_DIR}/include/fp.h" <<'EOF'
/* Stub header for legacy <fp.h> on modern Apple platforms. */
#ifndef FP_H_STUB
#define FP_H_STUB
#include <math.h>
#endif
EOF
  local PNG_EXTRA_CFLAGS="-I${PNG_FIX_DIR}/include"

  build_cmake_project_ios \
    "libpng-${variant_name}" \
    "${DOWNLOADS_DIR}/libpng-${LIBPNG_VERSION}" \
    "${build_root}/libpng-build" \
    "${install_prefix}" \
    "${sdk}" \
    "${arch}" \
    "${IOS_MIN_VERSION}" \
    "OFF" \
    "${PNG_EXTRA_CFLAGS}" \
    -DPNG_SHARED=OFF \
    -DPNG_TESTS=OFF

  # 3. libjpeg-turbo
  print_step "构建 libjpeg-turbo ${LIBJPEG_TURBO_VERSION} (${variant_name})"
  download_and_extract \
    "https://github.com/libjpeg-turbo/libjpeg-turbo/archive/${LIBJPEG_TURBO_VERSION}.tar.gz" \
    "libjpeg-turbo-${LIBJPEG_TURBO_VERSION}.tar.gz" \
    "libjpeg-turbo-${LIBJPEG_TURBO_VERSION}"

  # 针对 CMake 在 iOS 平台上可能未设置 CMAKE_SYSTEM_PROCESSOR 的情况
  local JPEG_SRC="${DOWNLOADS_DIR}/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}"
  local JPEG_CMAKELISTS="${JPEG_SRC}/CMakeLists.txt"
  if [[ -f "${JPEG_CMAKELISTS}" ]] && ! grep -q "Tesseract iOS: ensure CMAKE_SYSTEM_PROCESSOR" "${JPEG_CMAKELISTS}" >/dev/null 2>&1; then
    print_info "为 libjpeg-turbo 添加 iOS CMAKE_SYSTEM_PROCESSOR 修复 (${variant_name}) ..."
    local JPEG_TMP="${JPEG_CMAKELISTS}.tmp"
    awk '
      BEGIN { inserted = 0 }
      {
        print $0
        if (!inserted && $0 ~ /^project\(libjpeg-turbo C\)/) {
          print "# Tesseract iOS: ensure CMAKE_SYSTEM_PROCESSOR is not empty"
          print "if(NOT CMAKE_SYSTEM_PROCESSOR)"
          print "  if(CMAKE_OSX_ARCHITECTURES)"
          print "    set(CMAKE_SYSTEM_PROCESSOR \"${CMAKE_OSX_ARCHITECTURES}\")"
          print "  else()"
          print "    set(CMAKE_SYSTEM_PROCESSOR \"generic\")"
          print "  endif()"
          print "endif()"
          print "# End Tesseract iOS fix"
          inserted = 1
        }
      }
    ' "${JPEG_CMAKELISTS}" > "${JPEG_TMP}" && mv "${JPEG_TMP}" "${JPEG_CMAKELISTS}"
  fi

  build_cmake_project_ios \
    "libjpeg-turbo-${variant_name}" \
    "${DOWNLOADS_DIR}/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}" \
    "${build_root}/libjpeg-turbo-build" \
    "${install_prefix}" \
    "${sdk}" \
    "${arch}" \
    "${IOS_MIN_VERSION}" \
    "OFF" \
    "" \
    -DENABLE_SHARED=OFF \
    -DENABLE_STATIC=ON \
    -DWITH_TURBOJPEG=OFF

  # 4. libtiff
  print_step "构建 libtiff ${LIBTIFF_VERSION} (${variant_name})"
  download_and_extract \
    "https://download.osgeo.org/libtiff/tiff-${LIBTIFF_VERSION}.tar.gz" \
    "tiff-${LIBTIFF_VERSION}.tar.gz" \
    "tiff-${LIBTIFF_VERSION}"

  # 关键修复：强制禁用 libtiff 的所有可选依赖 (libdeflate, zstd, lzma, webp, jbig)
  build_cmake_project_ios \
    "libtiff-${variant_name}" \
    "${DOWNLOADS_DIR}/tiff-${LIBTIFF_VERSION}" \
    "${build_root}/libtiff-build" \
    "${install_prefix}" \
    "${sdk}" \
    "${arch}" \
    "${IOS_MIN_VERSION}" \
    "OFF" \
    "" \
    -Dtiff-tools=OFF \
    -Dtiff-tests=OFF \
    -Dtiff-contrib=OFF \
    -Dtiff-docs=OFF \
    -Dlibdeflate=OFF \
    -Dzstd=OFF \
    -Dlzma=OFF \
    -Dwebp=OFF \
    -Djbig=OFF

  # 5. leptonica
  print_step "构建 Leptonica ${LEPTONICA_VERSION} (${variant_name})"
  download_and_extract \
    "https://github.com/DanBloomberg/leptonica/releases/download/${LEPTONICA_VERSION}/leptonica-${LEPTONICA_VERSION}.tar.gz" \
    "leptonica-${LEPTONICA_VERSION}.tar.gz" \
    "leptonica-${LEPTONICA_VERSION}"

  # 关键修复：显式定义宏
  local LEPT_CFLAGS="-DHAVE_LIBPNG=1 -DHAVE_LIBJPEG=1 -DHAVE_LIBZ=1"
  
  build_cmake_project_ios \
    "leptonica-${variant_name}" \
    "${DOWNLOADS_DIR}/leptonica-${LEPTONICA_VERSION}" \
    "${build_root}/leptonica-build" \
    "${install_prefix}" \
    "${sdk}" \
    "${arch}" \
    "${IOS_MIN_VERSION}" \
    "OFF" \
    "${LEPT_CFLAGS}" \
    -DSTATIC=ON \
    -DSHARED=OFF \
    -DBUILD_PROG=OFF \
    -DBUILD_TESTS=OFF \
    -DENABLE_TIFF=OFF \
    -DENABLE_WEBP=OFF \
    -DENABLE_OPENJPEG=OFF \
    -DENABLE_GIF=OFF \
    -DENABLE_JPEG=ON \
    -DENABLE_PNG=ON \
    -DENABLE_ZLIB=ON \
    -DCMAKE_DISABLE_FIND_PACKAGE_Deflate=ON \
    -DPNG_LIBRARY="${install_prefix}/lib/libpng.a" \
    -DPNG_PNG_INCLUDE_DIR="${install_prefix}/include" \
    -DJPEG_LIBRARY="${install_prefix}/lib/libjpeg.a" \
    -DJPEG_INCLUDE_DIR="${install_prefix}/include" \
    -DZLIB_LIBRARY="${install_prefix}/lib/libz.a" \
    -DZLIB_INCLUDE_DIR="${install_prefix}/include"

  print_info "依赖库构建完成 (${variant_name})。"
}

#######################################
# 构建 iOS 依赖（真机 + 模拟器）
#######################################
build_dependencies_ios() {
  build_dependencies_ios_variant "iphoneos" "${IOS_ARCH_DEVICE}" "${INSTALL_PREFIX_IOS_DEVICE}" "ios-device"
  build_dependencies_ios_variant "iphonesimulator" "${IOS_ARCH_SIMULATOR}" "${INSTALL_PREFIX_IOS_SIMULATOR}" "ios-simulator"
}

#######################################
# 构建 Tesseract（静态 + 动态）
#######################################
build_tesseract() {
  print_head "开始构建 Tesseract ${TESSERACT_VERSION} ..."

  download_and_extract \
    "https://github.com/tesseract-ocr/tesseract/archive/refs/tags/${TESSERACT_VERSION}.tar.gz" \
    "tesseract-${TESSERACT_VERSION}.tar.gz" \
    "tesseract-${TESSERACT_VERSION}"
  local tess_src="${DOWNLOADS_DIR}/tesseract-${TESSERACT_VERSION}"

   # 修复：跳过 Leptonica TIFF try_run 检测（我们已确保本脚本构建的 Leptonica 启用 TIFF）
  local TESS_CHECK_FUN="${tess_src}/cmake/CheckFunctions.cmake"
  if [[ -f "${TESS_CHECK_FUN}" ]] && ! grep -q "Tesseract macOS: always skip Leptonica TIFF try_run" "${TESS_CHECK_FUN}" >/dev/null 2>&1; then
    print_info "为 Tesseract 修改 Leptonica TIFF 检测为静态结果 (macOS) ..."
    local TESS_CHECK_TMP="${TESS_CHECK_FUN}.tmp"
    awk '
      BEGIN { in_func = 0; done = 0 }
      /^function\(check_leptonica_tiff_support\)/ {
        print "function(check_leptonica_tiff_support)"
        print "  # Tesseract macOS: always skip Leptonica TIFF try_run (bundled Leptonica has TIFF enabled)"
        print "  set(LEPT_TIFF_RESULT 0 CACHE STRING \"Result of Leptonica TIFF test\" FORCE)"
        print "  set(LEPT_TIFF_COMPILE_SUCCESS 1 CACHE BOOL \"Leptonica TIFF test compile\" FORCE)"
        print "  return()"
        print "endfunction(check_leptonica_tiff_support)"
        in_func = 1
        done = 1
        next
      }
      {
        if (in_func) {
          if ($0 ~ /^endfunction\(check_leptonica_tiff_support\)/) {
            in_func = 0
          }
          next
        }
        print $0
      }
    ' "${TESS_CHECK_FUN}" > "${TESS_CHECK_TMP}" && mv "${TESS_CHECK_TMP}" "${TESS_CHECK_FUN}"
  fi

  # 初始化子模块
  if [[ -d "${tess_src}/.git" && ! -d "${tess_src}/unittest/third_party/googletest" ]]; then
    print_info "初始化 Tesseract 子模块..."
    (cd "${tess_src}" && git submodule update --init --recursive)
  fi

  # 关键修复：-DDISABLE_CURL=ON 避免依赖系统 curl
  build_cmake_project \
    "tesseract-static" \
    "${tess_src}" \
    "${BUILD_ROOT}/tesseract-build-static" \
    "${INSTALL_PREFIX}" \
    "OFF" \
    -DBUILD_TRAINING_TOOLS=OFF \
    -DBUILD_TESTS=OFF \
    -DGRAPHICS_DISABLED=ON \
    -DOPENMP_BUILD=OFF \
    -DUSE_SYSTEM_ICU=OFF \
    -DDISABLE_CURL=ON \
    -DLeptonica_DIR="${INSTALL_PREFIX}/lib/cmake/leptonica"

  print_info "Tesseract 构建完成。"
}

build_tesseract_ios_variant() {
  local sdk="$1"           # iphoneos / iphonesimulator
  local arch="$2"
  local install_prefix="$3"
  local variant_name="$4"

  print_head "开始构建 Tesseract ${TESSERACT_VERSION} (${variant_name}, ${sdk}, ${arch}, iOS >= ${IOS_MIN_VERSION}) ..."

  download_and_extract \
    "https://github.com/tesseract-ocr/tesseract/archive/refs/tags/${TESSERACT_VERSION}.tar.gz" \
    "tesseract-${TESSERACT_VERSION}.tar.gz" \
    "tesseract-${TESSERACT_VERSION}"
  local tess_src="${DOWNLOADS_DIR}/tesseract-${TESSERACT_VERSION}"

  # 为 iOS 交叉编译环境修正 Tesseract 的 try_run 检测：
  # macOS 构建阶段已将 check_leptonica_tiff_support 改为直接返回，
  # 这里无需再次修改。

  # 为 iOS 构建显式禁用 libcurl 链接
  local TESS_CMAKELISTS="${tess_src}/CMakeLists.txt"
  if [[ -f "${TESS_CMAKELISTS}" ]] && ! grep -q "Tesseract iOS: DISABLE_CURL also clears CURL_FOUND" "${TESS_CMAKELISTS}" >/dev/null 2>&1; then
    print_info "为 Tesseract 添加 iOS CURL 修复 (${variant_name}) ..."
    local TESS_CMAKE_TMP="${TESS_CMAKELISTS}.tmp"
    awk '
      BEGIN { patched = 0 }
      {
        print $0
        if (!patched && $0 ~ /^  if\(DISABLE_CURL\)/) {
          print "    # Tesseract iOS: DISABLE_CURL also clears CURL_FOUND to avoid linking libcurl on iOS"
          print "    set(CURL_FOUND OFF)"
          print "    set(CURL_LIBRARIES \"\")"
          print "    # End Tesseract iOS fix"
          patched = 1
        }
      }
    ' "${TESS_CMAKELISTS}" > "${TESS_CMAKE_TMP}" && mv "${TESS_CMAKE_TMP}" "${TESS_CMAKELISTS}"
  fi

  # 初始化子模块
  if [[ -d "${tess_src}/.git" && ! -d "${tess_src}/unittest/third_party/googletest" ]]; then
    print_info "初始化 Tesseract 子模块..."
    (cd "${tess_src}" && git submodule update --init --recursive)
  fi

  local build_root="${BUILD_ROOT_IOS}/${variant_name}"

  build_cmake_project_ios \
    "tesseract-static-${variant_name}" \
    "${tess_src}" \
    "${build_root}/tesseract-build-static" \
    "${install_prefix}" \
    "${sdk}" \
    "${arch}" \
    "${IOS_MIN_VERSION}" \
    "OFF" \
    "" \
    -DBUILD_TRAINING_TOOLS=OFF \
    -DBUILD_TESTS=OFF \
    -DDISABLE_CURL=ON \
    -DGRAPHICS_DISABLED=ON \
    -DOPENMP_BUILD=OFF \
    -DUSE_SYSTEM_ICU=OFF \
    -DLeptonica_DIR="${install_prefix}/lib/cmake/leptonica"

  print_info "Tesseract 构建完成 (${variant_name})。"
}

build_tesseract_ios() {
  build_tesseract_ios_variant "iphoneos" "${IOS_ARCH_DEVICE}" "${INSTALL_PREFIX_IOS_DEVICE}" "ios-device"
  build_tesseract_ios_variant "iphonesimulator" "${IOS_ARCH_SIMULATOR}" "${INSTALL_PREFIX_IOS_SIMULATOR}" "ios-simulator"
}

#######################################
# 针对指定安装前缀生成打包静态库
#######################################
post_process_for_prefix() {
  local prefix="$1"

  mkdir -p "${prefix}/lib" "${prefix}/include"

  # 创建打包静态库，方便项目只链接一个库
  local libs=()
  libs+=("${prefix}/lib/libtesseract.a")
  libs+=("${prefix}/lib/libleptonica.a")

  if [[ -f "${prefix}/lib/libpng16.a" ]]; then
    libs+=("${prefix}/lib/libpng16.a")
  elif [[ -f "${prefix}/lib/libpng.a" ]]; then
    libs+=("${prefix}/lib/libpng.a")
  else
    print_warn "未找到 libpng 静态库，将不会打包进 libtesseract_all.a (${prefix})."
  fi

  if [[ -f "${prefix}/lib/libjpeg.a" ]]; then
    libs+=("${prefix}/lib/libjpeg.a")
  elif [[ -f "${prefix}/lib/libjpeg-turbo.a" ]]; then
    libs+=("${prefix}/lib/libjpeg-turbo.a")
  else
    print_warn "未找到 libjpeg-turbo 静态库，将不会打包进 libtesseract_all.a (${prefix})."
  fi

  if [[ -f "${prefix}/lib/libtiff.a" ]]; then
    libs+=("${prefix}/lib/libtiff.a")
  else
    print_warn "未找到 libtiff 静态库，将不会打包进 libtesseract_all.a (${prefix})."
  fi

  if [[ -f "${prefix}/lib/libz.a" ]]; then
    libs+=("${prefix}/lib/libz.a")
  else
    print_warn "未找到 zlib 静态库，将不会打包进 libtesseract_all.a (${prefix})."
  fi

  if [[ ${#libs[@]} -gt 0 ]]; then
    create_unified_static_lib "${prefix}/lib/libtesseract_all.a" "${libs[@]}"
  else
    print_warn "没有可用的依赖静态库，跳过生成 libtesseract_all.a (${prefix})."
  fi

  # ====================================================================
  # 生成 Clang Module Map (module.modulemap)
  # ====================================================================
  print_info "生成 Clang Module Map (module.modulemap) ..."
  
  # 关键修复：添加自动链接 (link "c++", link "z", link "iconv")
  cat > "${prefix}/include/module.modulemap" <<EOF
module Tesseract {
    header "tesseract/capi.h"
    header "leptonica/allheaders.h"
    export *
    link "c++"
    link "z"
    link "iconv"
}
EOF
}

#######################################
# 生成打包静态库 + 头文件说明（macOS）
#######################################
post_process() {
  print_head "整理输出目录 (macOS) ..."

  post_process_for_prefix "${INSTALL_PREFIX}"

  # 清理所有动态库（仅保留静态 .a）
  if [[ -d "${INSTALL_PREFIX}/lib" ]]; then
    print_info "移除所有 .dylib（仅保留静态库）..."
    find "${INSTALL_PREFIX}/lib" -maxdepth 1 -name '*.dylib' -delete 2>/dev/null || true
  fi

  # 简要使用说明写入 README-build.md，便于离线查看
  cat > "${INSTALL_PREFIX}/README-build.md" <<EOF
Tesseract macOS arm64 构建结果
==============================

输出根目录：
  ${INSTALL_PREFIX}

关键文件：
  - lib/libtesseract.a        # Tesseract 静态库（依赖其他静态库）
  - lib/libtesseract.dylib    # Tesseract 动态库（若启用 BUILD_SHARED_LIBS_FLAG=ON）
  - lib/libtesseract_all.a    # 将 Tesseract + Leptonica + 基础图像库全部打包的静态库
  - include/module.modulemap  # Swift 模块映射文件 (新!)
  - include/                  # 头文件根目录

在 C 项目中使用：
  ... (同前)

在 Swift 项目中使用 (SPM / XCFramework)：
  直接 import Tesseract 即可，无需 Bridging Header。

EOF

  print_info "输出整理完成，可在 ${INSTALL_PREFIX} 中查看构建结果与 README-build.md。"
}

#######################################
# 为 iOS 安装前缀生成打包静态库
#######################################
post_process_ios() {
  print_head "整理输出目录 (iOS) ..."

  post_process_for_prefix "${INSTALL_PREFIX_IOS_DEVICE}"
  post_process_for_prefix "${INSTALL_PREFIX_IOS_SIMULATOR}"

  print_info "iOS 静态库整理完成，可在以下目录查看："
  echo "  - 真机: ${INSTALL_PREFIX_IOS_DEVICE}"
  echo "  - 模拟器: ${INSTALL_PREFIX_IOS_SIMULATOR}"
}

#######################################
# 生成 Tesseract.xcframework
#######################################
create_xcframework() {
  print_head "创建 Tesseract.xcframework ..."

  if ! command_exists xcodebuild; then
    print_warn "未找到 xcodebuild，无法生成 xcframework，已跳过。"
    return 0
  fi

  mkdir -p "${SCRIPT_DIR}/lib"
  local output_path="${SCRIPT_DIR}/lib/Tesseract.xcframework"
  rm -rf "${output_path}"

  local args=()

  # macOS
  if [[ -f "${INSTALL_PREFIX_MACOS}/lib/libtesseract_all.a" ]]; then
    args+=(-library "${INSTALL_PREFIX_MACOS}/lib/libtesseract_all.a" -headers "${INSTALL_PREFIX_MACOS}/include")
  else
    print_warn "未找到 macOS 版本的 libtesseract_all.a，无法生成 xcframework。"
    return 0
  fi

  # iOS 真机
  if [[ -f "${INSTALL_PREFIX_IOS_DEVICE}/lib/libtesseract_all.a" ]]; then
    args+=(-library "${INSTALL_PREFIX_IOS_DEVICE}/lib/libtesseract_all.a" -headers "${INSTALL_PREFIX_IOS_DEVICE}/include")
  else
    print_warn "未找到 iOS 真机版本的 libtesseract_all.a，将不会包含在 xcframework 中。"
  fi

  # iOS 模拟器
  if [[ -f "${INSTALL_PREFIX_IOS_SIMULATOR}/lib/libtesseract_all.a" ]]; then
    args+=(-library "${INSTALL_PREFIX_IOS_SIMULATOR}/lib/libtesseract_all.a" -headers "${INSTALL_PREFIX_IOS_SIMULATOR}/include")
  else
    print_warn "未找到 iOS 模拟器版本的 libtesseract_all.a，将不会包含在 xcframework 中。"
  fi

  if ((${#args[@]} < 4)); then
    print_warn "缺少 iOS 变体，暂不创建 xcframework。"
    return 0
  fi

  xcodebuild -create-xcframework "${args[@]}" -output "${output_path}"

  print_info "已生成 xcframework: ${output_path}"
}

#######################################
# 主流程
#######################################
main() {
  print_head "Tesseract macOS Apple Silicon 一键构建脚本"
  print_info "目标：macOS >= ${MACOS_MIN_VERSION}, 架构：${ARCH}, 构建类型：${BUILD_TYPE}"
  print_info "macOS 输出目录：${INSTALL_PREFIX}"
  if [[ "${ENABLE_IOS}" == "1" ]]; then
    print_info "iOS 真机输出目录：${INSTALL_PREFIX_IOS_DEVICE}"
    print_info "iOS 模拟器输出目录：${INSTALL_PREFIX_IOS_SIMULATOR}"
    print_info "iOS 最低版本：iOS ${IOS_MIN_VERSION}"
  fi
  echo

  check_macos_version
  check_dependencies

  # 【新增】彻底清理旧的构建产物，保留下载目录
  print_step "清理之前的构建环境 (保留下载目录)..."
  rm -rf "${BUILD_ROOT}" "${BUILD_ROOT_IOS}" "${INSTALL_PREFIX}" "${INSTALL_PREFIX_IOS_DEVICE}" "${INSTALL_PREFIX_IOS_SIMULATOR}" "${SCRIPT_DIR}/lib/Tesseract.xcframework"

  mkdir -p "${BUILD_ROOT}" "${BUILD_ROOT_IOS}" "${DOWNLOADS_DIR}" "${INSTALL_PREFIX}"
  if [[ "${ENABLE_IOS}" == "1" ]]; then
    mkdir -p "${INSTALL_PREFIX_IOS_DEVICE}" "${INSTALL_PREFIX_IOS_SIMULATOR}"
  fi

  # macOS 版本
  build_dependencies
  build_tesseract
  post_process

  # iOS 版本 + xcframework
  if [[ "${ENABLE_IOS}" == "1" ]]; then
    build_dependencies_ios
    build_tesseract_ios
    post_process_ios
    create_xcframework
  fi

  # 默认清理中间目录，只保留最终可用的产物；
  if [[ "${KEEP_INTERMEDIATE}" == "0" ]]; then
    print_head "清理中间构建目录 ..."
    rm -rf "${BUILD_ROOT}" "${BUILD_ROOT_IOS}" "${INSTALL_PREFIX_IOS_DEVICE}" "${INSTALL_PREFIX_IOS_SIMULATOR}"
    print_info "已清理 build-* 与 tesseract-ios-* 目录，仅保留："
    echo "  - macOS: ${INSTALL_PREFIX}  (如仅需 xcframework，可手动删除)"
    if [[ "${ENABLE_IOS}" == "1" ]]; then
      echo "  - xcframework: ${SCRIPT_DIR}/lib/Tesseract.xcframework"
    fi
  fi

  echo
  print_head "构建完成！"
  echo "  - 统一安装目录: ${INSTALL_PREFIX}"
  echo "  - 头文件路径:   ${INSTALL_PREFIX}/include"
  echo "  - 库文件路径:   ${INSTALL_PREFIX}/lib"
  if [[ "${ENABLE_IOS}" == "1" ]]; then
    echo "  - iOS 真机安装目录: ${INSTALL_PREFIX_IOS_DEVICE}"
    echo "  - iOS 模拟器安装目录: ${INSTALL_PREFIX_IOS_SIMULATOR}"
    echo "  - 生成的 xcframework: ${SCRIPT_DIR}/lib/Tesseract.xcframework (若 xcodebuild 可用)"
  fi
  echo
  echo "示例使用（C 项目）："
  echo "  export TESS_ROOT=\"${INSTALL_PREFIX}\""
  echo "  clang -std=c11 main.c \\"
  echo "    -I\"\${TESS_ROOT}/include\" \\"
  echo "    -L\"\${TESS_ROOT}/lib\" \\"
  echo "    -ltesseract_all \\"
  echo "    -framework CoreFoundation -framework CoreGraphics -framework ImageIO -framework Accelerate"
  echo
  echo "示例 Demo："
  echo "  - macOS: demo/macos/build_demo.sh"
  if [[ "${ENABLE_IOS}" == "1" ]]; then
    echo "  - iOS:   demo/ios (参见 README.md，并在 Xcode 中集成 Tesseract.xcframework)"
  fi
  echo
}

main "$@"
