#!/usr/bin/env bash
# ==============================================================================
# scripts/make-dmg.sh — VoiceInput：.app → 拖拽安装 DMG
# ==============================================================================
# 用法：
#   scripts/make-dmg.sh              # 构建 .app 并生成 DMG
#   scripts/make-dmg.sh --no-build   # 复用已有 build/VoiceInput.app，仅重打 DMG
#   scripts/make-dmg.sh --help       # 查看本说明
#
# 产物：dist/VoiceInput-<版本>.dmg（dist/ 已被 .gitignore 忽略）
# 布局：DMG 根目录 = VoiceInput.app + /Applications 软链（拖拽安装）
# 签名：随 .app 一起 ad-hoc（个人自用，不公证）
# ==============================================================================

set -euo pipefail

# 失败时清掉半成品，避免留下损坏的 DMG 或残留挂载点
trap 'status=$?; if [[ $status -ne 0 ]]; then [[ -n "${DMG_PATH:-}" ]] && rm -f "${DMG_PATH}"; [[ -n "${MOUNT_DIR:-}" && -d "${MOUNT_DIR:-}" ]] && hdiutil detach "${MOUNT_DIR}" -quiet 2>/dev/null || true; fi; [[ -n "${RW_DMG:-}" ]] && rm -f "${RW_DMG}"; [[ -n "${STAGE_DIR:-}" && -d "${STAGE_DIR:-}" ]] && rm -rf "${STAGE_DIR}"; exit $status' EXIT

APP_NAME="VoiceInput"
MIN_MACOS="14.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
DIST_DIR="${PROJECT_ROOT}/dist"

DO_BUILD=1

usage() {
    cat <<'USAGE'
用法：
  scripts/make-dmg.sh              # 构建 .app 并生成 DMG
  scripts/make-dmg.sh --no-build   # 复用已有 build/VoiceInput.app，仅重打 DMG
  scripts/make-dmg.sh --help       # 查看本说明

产物：dist/VoiceInput-<版本>.dmg（版本取自 .app 的 Info.plist）
布局：VoiceInput.app + /Applications 软链，打开 DMG 拖拽即可安装
USAGE
}

# --- 1. 参数解析 -------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-build)
            DO_BUILD=0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "错误: 未知参数 '$1'（用 --help 查看用法）" >&2
            exit 2
            ;;
    esac
    shift
done

echo "==> 项目根目录: ${PROJECT_ROOT}"

# --- 2. 构建 / 复用 .app -----------------------------------------------------
cd "${PROJECT_ROOT}"
if [[ "${DO_BUILD}" -eq 1 ]]; then
    echo "==> [1/4] 构建 .app ..."
    "${SCRIPT_DIR}/bundle-app.sh"
else
    echo "==> [1/4] 跳过构建（--no-build）"
fi

if [[ ! -d "${APP_DIR}" ]]; then
    echo "错误: 未找到 ${APP_DIR}，请先运行 scripts/bundle-app.sh" >&2
    exit 1
fi

# 版本号以构建产物为准，避免与 bundle-app.sh 的常量两处维护
VERSION="$(defaults read "${APP_DIR}/Contents/Info" CFBundleShortVersionString)"
if [[ -z "${VERSION}" ]]; then
    echo "错误: 无法从 Info.plist 读取版本号" >&2
    exit 1
fi

DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
echo "    版本: ${VERSION}"

# --- 3. 组装拖拽安装布局 -----------------------------------------------------
echo "==> [2/4] 组装 DMG 内容 ..."
STAGE_DIR="$(mktemp -d "${BUILD_DIR}/dmg-stage.XXXXXX")"
# ditto 复制 bundle：保留符号链接与扩展属性，签名不被破坏
ditto "${APP_DIR}" "${STAGE_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGE_DIR}/Applications"

mkdir -p "${DIST_DIR}"
rm -f "${DMG_PATH}"

# --- 4. 生成压缩 DMG ---------------------------------------------------------
echo "==> [3/4] 生成 DMG ..."
# 先建可写镜像才能给卷根打上自定义图标标记，再转成压缩格式
RW_DMG="$(mktemp -u "${BUILD_DIR}/dmg-rw.XXXXXX.dmg")"
hdiutil create \
    -volname "${APP_NAME} ${VERSION}" \
    -srcfolder "${STAGE_DIR}" \
    -fs HFS+ \
    -format UDRW \
    -ov \
    "${RW_DMG}" >/dev/null

MOUNT_DIR="$(mktemp -d "${BUILD_DIR}/dmg-mount.XXXXXX")"
hdiutil attach "${RW_DMG}" -nobrowse -mountpoint "${MOUNT_DIR}" >/dev/null
if [[ -f "${PROJECT_ROOT}/Resources/AppIcon.icns" ]]; then
    cp "${PROJECT_ROOT}/Resources/AppIcon.icns" "${MOUNT_DIR}/.VolumeIcon.icns"
    SetFile -a C "${MOUNT_DIR}"
fi
sync
hdiutil detach "${MOUNT_DIR}" -quiet
rm -rf "${MOUNT_DIR}"
MOUNT_DIR=""

hdiutil convert "${RW_DMG}" -format UDZO -o "${DMG_PATH}" >/dev/null
rm -f "${RW_DMG}"

rm -rf "${STAGE_DIR}"
STAGE_DIR=""

# 不要对 DMG 再做 codesign：UDIF 要求 koly 块是文件最后 512 字节，
# 而 codesign 会在 koly 之后追加签名数据，导致 Finder 报「未能打开磁盘映像 / URL 格式错误」。
# 应用本身已在 bundle-app.sh 中完成 ad-hoc 签名。

# --- 5. 校验 -----------------------------------------------------------------
echo "==> [4/4] 校验 ..."
hdiutil verify "${DMG_PATH}"

echo ""
echo "==> DMG 打包完成: ${DMG_PATH}"
echo "    大小: $(du -h "${DMG_PATH}" | cut -f1)"
echo "    安装: 双击打开，把 ${APP_NAME}.app 拖到 /Applications"
