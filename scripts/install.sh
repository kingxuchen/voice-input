#!/usr/bin/env bash
# ==============================================================================
# scripts/install.sh — 一条命令装好 VoiceInput（含 helper），绕开 Gatekeeper 拦截
# ==============================================================================
# 用法：
#   curl -fsSL https://raw.githubusercontent.com/kingxuchen/voice-input/main/scripts/install.sh | bash
#
# 为什么是脚本而不是 dmg：ad-hoc 签名 + 网络下载会被 Gatekeeper 判「已损坏」，
# macOS 15 起连右键打开都被移除。脚本负责校验和、解压、清隔离属性，让用户零拦截。
#
# 环境变量（都有默认值，正常安装不需要动）：
#   VERSION  指定版本（如 v1.0.0），默认取 latest release
#   BASE_URL 覆盖下载来源（镜像 / 离线自检用），默认取 GitHub Release 地址
# ==============================================================================

set -euo pipefail

APP_NAME="VoiceInput"
BUNDLE_ID="com.fanbingbing.voiceinput"
REPO="kingxuchen/voice-input"
DEST_DIR="${HOME}/Applications"
DEST_APP="${DEST_DIR}/${APP_NAME}.app"
STAGING="${DEST_DIR}/.${APP_NAME}.app.incoming"

fail() {
    echo "安装失败: $*" >&2
    exit 1
}

TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "${TMP_DIR}" "${STAGING}"
}
trap cleanup EXIT

# --- 1. 解析版本 -------------------------------------------------------------
# 注意：本脚本开了 pipefail，curl/grep 失败会让整条赋值失败并当场退出，
# 所以这里显式兜底（`|| true`）再由空值判断给出可读的错误。
if [[ -n "${VERSION:-}" ]]; then
    TAG="${VERSION}"
else
    echo "==> 查询最新版本 ..."
    API_JSON="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" || true)"
    TAG="$(printf '%s' "${API_JSON}" \
        | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/' || true)"
    [[ -n "${TAG}" ]] || fail "查不到最新版本（可显式指定 VERSION=v1.0.0，或检查网络）"
fi

VERSION_NUMBER="${TAG#v}"
ZIP_NAME="${APP_NAME}-${VERSION_NUMBER}.zip"
BASE_URL="${BASE_URL:-https://github.com/${REPO}/releases/download/${TAG}}"

echo "==> 版本: ${TAG}"

# --- 2. 下载并校验 -----------------------------------------------------------
echo "==> 下载 ${ZIP_NAME} ..."
curl -fsSL "${BASE_URL}/${ZIP_NAME}" -o "${TMP_DIR}/${ZIP_NAME}" || fail "下载失败: ${BASE_URL}/${ZIP_NAME}"
curl -fsSL "${BASE_URL}/${ZIP_NAME}.sha256" -o "${TMP_DIR}/${ZIP_NAME}.sha256" || fail "下载校验和失败"

echo "==> 校验 SHA-256 ..."
( cd "${TMP_DIR}" && shasum -a 256 -c "${ZIP_NAME}.sha256" >/dev/null ) \
    || fail "校验和不匹配，已中止（下载文件可能损坏或被篡改）"

# --- 3. 解压并预检（都在暂存区完成，不碰已安装的 App）----------------------
echo "==> 解压 ..."
ditto -x -k "${TMP_DIR}/${ZIP_NAME}" "${TMP_DIR}/unpacked" || fail "解压失败"

SRC_APP="${TMP_DIR}/unpacked/${APP_NAME}.app"
[[ -d "${SRC_APP}" ]] || fail "压缩包里没有 ${APP_NAME}.app"

SRC_HELPER="${SRC_APP}/Contents/MacOS/voiceinput-cli"
[[ -x "${SRC_HELPER}" ]] || fail "安装包里没有 helper（${SRC_HELPER}），请确认下载的是含 CLI 的版本"
"${SRC_HELPER}" version >/dev/null || fail "helper 自检失败，安装包不可用"

# --- 4. 原子替换：先装到暂存路径，确认无误后才替换旧 App -------------------
# 直接 rm 旧再复制的话，中途失败会留下"旧版没了、新版是坏的"这种最坏结果。
echo "==> 安装到 ${DEST_APP} ..."
mkdir -p "${DEST_DIR}"
rm -rf "${STAGING}"
ditto "${SRC_APP}" "${STAGING}" || fail "复制到暂存路径失败"
xattr -cr "${STAGING}" || fail "清除隔离属性失败"
"${STAGING}/Contents/MacOS/voiceinput-cli" version >/dev/null || fail "暂存安装的文件无法运行，已放弃替换"

if [[ -e "${DEST_APP}" ]]; then
    # 与 bundle-app.sh 一致：先确认目标位置是不是本应用，避免静默删掉同名但来源不明的 App
    EXISTING_ID="$(defaults read "${DEST_APP}/Contents/Info" CFBundleIdentifier 2>/dev/null || echo "未知")"
    [[ "${EXISTING_ID}" == "${BUNDLE_ID}" ]] \
        || fail "目标位置已存在来源不明的同名应用（bundle id = ${EXISTING_ID}）。已中止，未做改动。"
    if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
        echo "    提示: ${APP_NAME} 正在运行，安装完成后请重启它以加载新版本。"
    fi
    rm -rf "${DEST_APP}"
fi

mv "${STAGING}" "${DEST_APP}" || fail "替换 ${DEST_APP} 失败"

# --- 5. 完成 ----------------------------------------------------------------
HELPER="${DEST_APP}/Contents/MacOS/voiceinput-cli"
echo ""
echo "==> 安装完成: ${DEST_APP}"
echo "    helper: ${HELPER}"
echo "    在 Raycast 里运行「Switch Audio Input」即可切换输入音源。"

open "${DEST_APP}" || true
