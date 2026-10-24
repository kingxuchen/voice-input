#!/usr/bin/env bash
# ==============================================================================
# scripts/release.sh — 打包可分发产物，并打印发布命令（不自动上传）
# ==============================================================================
# 用法：
#   scripts/release.sh
#
# 产物：
#   dist/VoiceInput-<version>.zip         （ditto 打包，保留签名与扩展属性）
#   dist/VoiceInput-<version>.zip.sha256  （install.sh 校验用）
#
# 刻意不自动 tag / push / 上传：发布是外部可见动作，交由人确认后执行脚本打印的命令。
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_NAME="VoiceInput"
REPO="kingxuchen/voice-input"

# 版本唯一来源：bundle-app.sh 里的 VERSION（helper 的 version 输出同源）
VERSION="$(grep -m1 '^VERSION=' "${SCRIPT_DIR}/bundle-app.sh" | cut -d'"' -f2 || true)"
[[ -n "${VERSION}" ]] || { echo "发布失败: 无法从 bundle-app.sh 读到 VERSION" >&2; exit 1; }

TAG="v${VERSION}"
DIST_DIR="${PROJECT_ROOT}/dist"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.zip"

echo "==> 构建 ${TAG} ..."
"${SCRIPT_DIR}/bundle-app.sh"

APP_PATH="${PROJECT_ROOT}/build/${APP_NAME}.app"
[[ -d "${APP_PATH}" ]] || { echo "发布失败: 未找到 ${APP_PATH}" >&2; exit 1; }

echo "==> 打包 ${ZIP_PATH} ..."
mkdir -p "${DIST_DIR}"
rm -f "${ZIP_PATH}" "${ZIP_PATH}.sha256"
# 必须用 ditto：保留符号链接、扩展属性与代码签名封印（普通 zip 会破坏签名）
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo "==> 计算校验和 ..."
( cd "${DIST_DIR}" && shasum -a 256 "${APP_NAME}-${VERSION}.zip" > "${APP_NAME}-${VERSION}.zip.sha256" )

echo ""
echo "==> 产物就绪："
ls -l "${ZIP_PATH}" "${ZIP_PATH}.sha256" | sed 's/^/    /'
echo ""
echo "==> 发布步骤（手动执行）："
echo "    git tag ${TAG} && git push origin ${TAG}"
echo "    gh release create ${TAG} \\"
echo "        '${ZIP_PATH}' \\"
echo "        '${ZIP_PATH}.sha256' \\"
echo "        --repo ${REPO} --title '${APP_NAME} ${VERSION}' --notes '见 CHANGELOG'"
echo ""
echo "==> 发布后自检："
echo "    VERSION=${TAG} bash \"${SCRIPT_DIR}/install.sh\""
