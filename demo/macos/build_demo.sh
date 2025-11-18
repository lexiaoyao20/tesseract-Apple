#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/../.."
TESS_ROOT="${REPO_ROOT}/tesseract-macos-arm64"

if [[ ! -d "${TESS_ROOT}" ]]; then
  echo "[ERROR] 未找到 ${TESS_ROOT}，请先在仓库根目录运行 ./build.sh 构建 macOS 版本。"
  exit 1
fi

echo "[BUILD] 使用 ${TESS_ROOT} 中的头文件和库构建 macOS 演示程序..."

clang -std=c11 "${SCRIPT_DIR}/main.c" \
  -I"${TESS_ROOT}/include" \
  -L"${TESS_ROOT}/lib" \
  -ltesseract_all \
  -framework CoreFoundation \
  -framework CoreGraphics \
  -framework ImageIO \
  -framework Accelerate \
  -o "${SCRIPT_DIR}/tesseract-demo"

echo "[INFO] 构建完成，可运行：${SCRIPT_DIR}/tesseract-demo"

