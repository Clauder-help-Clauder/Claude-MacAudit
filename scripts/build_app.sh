#!/bin/bash
# MacAudit 构建脚本 — 同时输出 TUI 裸二进制 + GUI .app bundle
# 用法：./scripts/build_app.sh [debug|release]
#
# 目录结构：
#   .spm-build/        ← SPM 编译缓存（隐藏，不要手动修改）
#   debug/             ← debug 产物（日常测试用）
#     MacAudit              TUI 裸二进制
#     MacAuditApp           GUI 裸二进制
#     MacAuditApp.app/      GUI 完整 bundle（带 icon + 字体）⭐ 发给测试机用这个
#   release/v<VERSION>/  ← 正式发版归档
#     MacAudit
#     MacAuditApp
#     MacAuditApp.app/

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BASE_DIR="$(dirname "$PROJECT_DIR")"

VERSION=$(grep 'static let version' "$PROJECT_DIR/Sources/MacAuditUI/ViewModels/AppViewModel.swift" \
    | head -1 | sed 's/.*"\(.*\)".*/\1/')
MODE="${1:-debug}"

# SPM 缓存统一放 .spm-build/，产物放 debug/ 或 release/v<VERSION>/
SPM_BUILD="$BASE_DIR/.spm-build/$MODE"

if [ "$MODE" = "release" ]; then
    OUT_DIR="$BASE_DIR/release/$VERSION"
    BINARY_SUBDIR="apple/Products/Release"
    SWIFT_FLAGS="-c release --arch arm64 --arch x86_64"
else
    OUT_DIR="$BASE_DIR/debug"
    BINARY_SUBDIR="apple/Products/Debug"
    SWIFT_FLAGS="--arch arm64 --arch x86_64"
fi

# Strip developer paths from binaries (privacy: remove /Users/xxx from debug symbols)
STRIP_PREFIX="-Xswiftc -debug-prefix-map -Xswiftc $PROJECT_DIR=. -Xswiftc -debug-prefix-map -Xswiftc $HOME=/dev/null"
SWIFT_FLAGS="$SWIFT_FLAGS $STRIP_PREFIX"

mkdir -p "$SPM_BUILD" "$OUT_DIR"

# plist 版本号去掉 v 前缀（Apple 惯例裸数字）
VERSION_PLIST="${VERSION#v}"
# 裸二进制用横线版本号（避免 macOS 把 .5 当扩展名）；.app 保留原版本号
VERSION_DASH="${VERSION//./-}"
TUI_OUT="$OUT_DIR/MacAudit-CLI-$VERSION_DASH"
APP_BUNDLE="$OUT_DIR/MacAudit-GUI-$VERSION.app"
BINARY_DIR="$SPM_BUILD/$BINARY_SUBDIR"

# ── 0. 拉取最新 proxy_rules.md ────────────────────────────
PROXY_MD="$PROJECT_DIR/Sources/MacAuditUI/Resources/proxy_rules.md"
echo "▶ Fetching proxy_rules.md from GitHub …"
curl -sL "https://raw.githubusercontent.com/Clauder-help-Clauder/Claude-MacAudit/main/docs/proxy_rules.md" -o "$PROXY_MD" || echo "  ⚠ Fetch failed, using cached version"

# ── 1. 编译 ────────────────────────────────────────────────
echo "▶ Building TUI + GUI ($MODE, version $VERSION) …"
cd "$PROJECT_DIR"
swift build $SWIFT_FLAGS --product MacAudit    --build-path "$SPM_BUILD"
swift build $SWIFT_FLAGS --product MacAuditApp --build-path "$SPM_BUILD"

# ── 2. 拷贝 CLI 二进制到产物目录 ──────────────────────────
cp "$BINARY_DIR/MacAudit" "$TUI_OUT"

# ── 3. 打包 .app bundle ─────────────────────────────────────
echo "▶ Packaging MacAuditApp.app …"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY_DIR/MacAuditApp" "$APP_BUNDLE/Contents/MacOS/MacAuditApp"

# SPM 资源 bundle（字体，Bundle.module 依赖此文件）
# ⚠️ 必须放 Contents/Resources/（SPM 生成的 accessor 只搜 resourceURL / bundleURL，不搜 MacOS/）
for bundle in "$BINARY_DIR"/*.bundle; do
    [ -e "$bundle" ] && cp -r "$bundle" "$APP_BUNDLE/Contents/Resources/"
done

# proxy_rules.md（构建时从 GitHub 拉取的最新版，SPM bundle 已包含，此处冗余备份）
[ -f "$PROXY_MD" ] && cp "$PROXY_MD" "$APP_BUNDLE/Contents/Resources/proxy_rules.md"

# AppIcon
ICNS="$PROJECT_DIR/Resources/Icons/AppIcon.icns"
[ -f "$ICNS" ] && cp "$ICNS" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MacAudit</string>
    <key>CFBundleDisplayName</key>
    <string>MacAudit</string>
    <key>CFBundleIdentifier</key>
    <string>com.macaudit.gui</string>
    <key>CFBundleVersion</key>
    <string>$VERSION_PLIST</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION_PLIST</string>
    <key>CFBundleExecutable</key>
    <string>MacAuditApp</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

xattr -dr com.apple.quarantine "$APP_BUNDLE" 2>/dev/null || true

# ── 4. 汇总 ─────────────────────────────────────────────────
echo ""
echo "✅ Done ($MODE, $VERSION)"
echo "   CLI : $TUI_OUT"
echo "   GUI : $APP_BUNDLE"
[ "$MODE" = "debug" ] && echo "" && echo "   Run: open \"$APP_BUNDLE\""
