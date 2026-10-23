#!/usr/bin/env bash
# ==============================================================================
# scripts/bundle-app.sh — VoiceInput：SwiftPM 构建产物 → 可双击运行的 ad-hoc .app
# ==============================================================================
# 用法：
#   scripts/bundle-app.sh                        # 构建 → 组装 → 校验 → 签名
#   scripts/bundle-app.sh --install              # 额外安装到 ~/Applications
#   scripts/bundle-app.sh --install /Applications # 安装到指定目录
#   scripts/bundle-app.sh --no-build             # 跳过 swift build，仅重新组装
#   scripts/bundle-app.sh --help                 # 查看本说明
#
# 产物：build/VoiceInput.app（build/ 与 *.app 均已被 .gitignore 忽略）
# 签名：ad-hoc（个人自用，不公证、不使用 Developer ID）
# 依据：research/swiftpm-app-bundling.md 第 7 节模板 + SPEC 0006 决策
# ==============================================================================

set -euo pipefail

# 失败时清掉半成品 .app，避免留下一个未签名/不完整的 bundle 被误双击
trap 'status=$?; if [[ $status -ne 0 && -n "${APP_DIR:-}" ]]; then rm -rf "${APP_DIR}"; echo "构建失败，已清理半成品 ${APP_DIR}" >&2; fi' EXIT

# --- 1. 常量（SPEC 0006 定稿：Bundle ID 全小写 voiceinput）------------------
APP_NAME="VoiceInput"
BUNDLE_ID="com.fanbingbing.voiceinput"
VERSION="1.0.0"
BUILD_NUMBER="1"
MIN_MACOS="14.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

INSTALL_DIR=""
DO_BUILD=1

usage() {
    cat <<'USAGE'
用法：
  scripts/bundle-app.sh                        # 构建 → 组装 → 校验 → 签名
  scripts/bundle-app.sh --install              # 额外安装到 ~/Applications
  scripts/bundle-app.sh --install /Applications # 安装到指定目录
  scripts/bundle-app.sh --no-build             # 跳过 swift build，仅重新组装
  scripts/bundle-app.sh --help                 # 查看本说明

产物：build/VoiceInput.app（build/ 与 *.app 均已被 .gitignore 忽略）
签名：ad-hoc（个人自用，不公证、不使用 Developer ID）
USAGE
}

# --- 2. 参数解析 -------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --install)
            # 不带路径时默认装到用户目录 ~/Applications（写 /Applications 需管理员权限）
            if [[ $# -ge 2 && -n "${2:-}" && "${2:-}" != -* ]]; then
                INSTALL_DIR="$2"
                shift
            else
                INSTALL_DIR="${HOME}/Applications"
            fi
            ;;
        --install=*)
            INSTALL_DIR="${1#*=}"
            ;;
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

if [[ -n "${INSTALL_DIR}" ]]; then
    # 统一去掉尾部斜杠，避免拼出 "/Applications//VoiceInput.app"
    INSTALL_DIR="${INSTALL_DIR%/}"
fi

echo "==> 项目根目录: ${PROJECT_ROOT}"

# --- 3. 构建并动态定位产物 ---------------------------------------------------
# 产物路径必须由 SwiftPM 解析，禁止写死 .build/ 或 arm64-apple-macosx 之类的架构路径
cd "${PROJECT_ROOT}"
if [[ "${DO_BUILD}" -eq 1 ]]; then
    echo "==> [1/5] SwiftPM Release 构建 ..."
    swift build -c release
else
    echo "==> [1/5] 跳过构建（--no-build）"
fi

echo "==> [2/5] 解析构建产物目录 ..."
BIN_DIR_RAW="$(swift build -c release --show-bin-path)"
# --show-bin-path 可能附带额外输出行，取最后一个非空行
# （grep 无匹配时返回 1，pipefail 下会中断脚本，这里用 || true 兜底后再判空）
BIN_DIR="$(printf '%s\n' "${BIN_DIR_RAW}" | grep -v '^[[:space:]]*$' | tail -n 1 || true)"

if [[ -z "${BIN_DIR}" || ! -d "${BIN_DIR}" ]]; then
    echo "错误: 无法解析 SwiftPM 产物目录: '${BIN_DIR}'" >&2
    exit 1
fi
echo "    BIN_DIR = ${BIN_DIR}"

SRC_BIN="${BIN_DIR}/${APP_NAME}"
if [[ ! -f "${SRC_BIN}" ]]; then
    echo "错误: 未找到可执行文件 '${SRC_BIN}'。" >&2
    echo "      SwiftPM 的 executable product 名必须与 App 名一致（${APP_NAME}）。当前目录内的候选项：" >&2
    find "${BIN_DIR}" -maxdepth 1 -type f -perm -111 ! -name "*.dylib" -print | sed 's/^/      /' >&2
    exit 1
fi

# --- 4. 组装标准 .app bundle 目录 -------------------------------------------
echo "==> [3/5] 组装 .app Bundle 目录结构 ..."
# 幂等：先删掉旧产物再重建，避免残留上一次的旧文件
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${SRC_BIN}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# PkgInfo：传统应用类型声明（APPL????），现代 macOS 可读但仍是标准结构的一部分
printf 'APPL????' > "${CONTENTS_DIR}/PkgInfo"

# SwiftPM 资源束：Target 声明 resources 时 swift build 会在产物目录生成
# <Package>_<Target>.bundle，运行期 Bundle.module 找不到它会直接 Fatal Error（P-07）
for bundle in "${BIN_DIR}"/*.bundle; do
    [[ -e "${bundle}" ]] || continue
    echo "    拷贝资源束: $(basename "${bundle}")"
    cp -R "${bundle}" "${RESOURCES_DIR}/"
done

# 应用图标（可选，0007 若提供 Resources/AppIcon.icns 会被打进 bundle）
ICON_KEY=""
if [[ -f "${PROJECT_ROOT}/Resources/AppIcon.icns" ]]; then
    cp "${PROJECT_ROOT}/Resources/AppIcon.icns" "${RESOURCES_DIR}/"
    ICON_KEY="
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>"
fi

echo "==> [4/5] 生成 Info.plist 并做 plutil -lint 校验 ..."
cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <!-- 静态声明 Accessory 进程：LaunchServices 拉起前就注入激活策略，
         避免运行期再调 setActivationPolicy 导致 Dock 图标闪烁（P-05） -->
    <key>LSUIElement</key>
    <true/>
${ICON_KEY}
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

plutil -lint "${CONTENTS_DIR}/Info.plist"

# --- 5. ad-hoc 签名 ----------------------------------------------------------
echo "==> [5/5] ad-hoc 代码签名 ..."
# 只对 .app 根签名，不加 --deep：本项目是单二进制 bundle，inside-out 签名即可；
# --deep 会用外层参数重签嵌套构件，破坏其自带 entitlements / designated requirement（P-03）
codesign --force --sign - --timestamp=none "${APP_DIR}"
codesign --verify --strict --verbose=2 "${APP_DIR}"

echo ""
echo "==> 打包完成: ${APP_DIR}"
echo "    Bundle ID   : ${BUNDLE_ID}"
echo "    LSUIElement : true（不占 Dock，无主窗口）"
echo "    最低系统    : ${MIN_MACOS}"

# --- 6. 可选安装 -------------------------------------------------------------
if [[ -n "${INSTALL_DIR}" ]]; then
    TARGET="${INSTALL_DIR}/${APP_NAME}.app"
    echo ""
    echo "==> 安装到: ${TARGET}"

    if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
        echo "    提示: 检测到 ${APP_NAME} 正在运行，覆盖安装后请重启进程以加载新版本。"
    fi

    # 覆盖前先看一眼已存在的是什么：来源不明的同名 app 不应被静默删掉
    if [[ -e "${TARGET}" ]]; then
        EXISTING_ID="$(defaults read "${TARGET}/Contents/Info" CFBundleIdentifier 2>/dev/null || echo "未知")"
        if [[ "${EXISTING_ID}" != "${BUNDLE_ID}" ]]; then
            echo "错误: 目标位置已存在来源不明的同名应用（bundle id = ${EXISTING_ID}，期望 ${BUNDLE_ID}）。" >&2
            echo "      已中止，未做任何改动。请手动确认后再安装。" >&2
            exit 1
        fi
    fi

    mkdir -p "${INSTALL_DIR}"
    rm -rf "${TARGET}"
    # ditto 复制 bundle：保留符号链接与扩展属性（cp -R 不保留扩展属性）
    ditto "${APP_DIR}" "${TARGET}"

    # 确认复制后签名仍然有效
    codesign --verify --strict --verbose=2 "${TARGET}"
    echo "    安装就绪: ${TARGET}"
fi
