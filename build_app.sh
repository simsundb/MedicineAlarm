#!/bin/bash
#
# 编译 → 打包成 .app → ad-hoc 签名 → 安装到「应用程序」目录 → 启动。
#
# 用法:
#   ./build_app.sh              编译并安装到 ~/Applications/吃药提醒.app
#   ./build_app.sh --no-install 只编译打包，不安装
#   ./build_app.sh --no-launch  安装但不自动启动
#
# 环境变量:
#   INSTALL_DIR   改安装位置，默认 ~/Applications（用 /Applications 需要管理员权限）
#
set -euo pipefail

APP_NAME="MedicineAlarm"          # 可执行文件名 / SwiftPM target
INSTALL_NAME="吃药提醒"             # 安装后 .app 的名字（Finder 里看到的）
BUNDLE_ID="com.sunzh.medicine-alarm"
VERSION="1.0.0"
MIN_MACOS="14.0"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/build"
STAGE_APP="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
INSTALLED_APP="$INSTALL_DIR/$INSTALL_NAME.app"

DO_INSTALL=1
DO_LAUNCH=1
for arg in "$@"; do
    case "$arg" in
        --no-install) DO_INSTALL=0 ;;
        --no-launch)  DO_LAUNCH=0 ;;
        -h|--help)    sed -n '2,15p' "$0"; exit 0 ;;
        *) echo "未知参数: $arg" >&2; exit 1 ;;
    esac
done

step() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m警告:\033[0m %s\n' "$1"; }

# ---------------------------------------------------------------- 1. 编译
step "编译 (release)"
swift build -c release --package-path "$ROOT"
BIN_PATH="$(swift build -c release --package-path "$ROOT" --show-bin-path)/$APP_NAME"

if [ ! -x "$BIN_PATH" ]; then
    echo "编译产物不存在: $BIN_PATH" >&2
    exit 1
fi

# ---------------------------------------------------------------- 2. 图标
step "生成图标"
ICNS="$BUILD_DIR/AppIcon.icns"
if [ ! -f "$ICNS" ] || [ "$ROOT/Resources/make_icon.swift" -nt "$ICNS" ]; then
    rm -rf "$BUILD_DIR/AppIcon.iconset"
    if swift "$ROOT/Resources/make_icon.swift" "$BUILD_DIR/AppIcon.iconset" >/dev/null \
       && iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$ICNS" 2>/dev/null; then
        echo "图标已生成: $ICNS"
    else
        warn "图标生成失败，将使用系统默认图标"
        ICNS=""
    fi
else
    echo "复用已有图标: $ICNS"
fi

# ---------------------------------------------------------------- 3. 组装 bundle
step "组装 $APP_NAME.app"
rm -rf "$STAGE_APP"
mkdir -p "$STAGE_APP/Contents/MacOS" "$STAGE_APP/Contents/Resources"
cp "$BIN_PATH" "$STAGE_APP/Contents/MacOS/$APP_NAME"

ICON_ENTRY=""
if [ -n "$ICNS" ] && [ -f "$ICNS" ]; then
    cp "$ICNS" "$STAGE_APP/Contents/Resources/AppIcon.icns"
    ICON_ENTRY="    <key>CFBundleIconFile</key>
    <string>AppIcon</string>"
fi

cat > "$STAGE_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$INSTALL_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$INSTALL_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
$ICON_ENTRY
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

plutil -lint "$STAGE_APP/Contents/Info.plist" >/dev/null

printf 'APPL????' > "$STAGE_APP/Contents/PkgInfo"

# ---------------------------------------------------------------- 4. 签名
# 本机没有 Developer ID（security find-identity 返回 0 个身份），
# 所以用 ad-hoc 签名。够本机运行；缺点是不能公证、换机器要重新签。
step "ad-hoc 签名"
codesign --force --sign - --identifier "$BUNDLE_ID" "$STAGE_APP"
codesign --verify --verbose=2 "$STAGE_APP" 2>&1 | sed 's/^/    /'

if [ "$DO_INSTALL" -eq 0 ]; then
    step "完成（未安装）"
    echo "产物: $STAGE_APP"
    exit 0
fi

# ---------------------------------------------------------------- 5. 安装
step "安装到 $INSTALLED_APP"

# 先停掉正在运行的旧副本，否则替换后菜单栏会留着上一个进程
pkill -f "$INSTALLED_APP/Contents/MacOS/$APP_NAME" 2>/dev/null || true
pkill -f "$STAGE_APP/Contents/MacOS/$APP_NAME" 2>/dev/null || true
sleep 1

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALLED_APP"
cp -R "$STAGE_APP" "$INSTALLED_APP"

# 让 LaunchServices 立刻认识这个 app（影响 Spotlight / 通知 / open 命令）
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$INSTALLED_APP" || true

# ---------------------------------------------------------------- 6. 启动
if [ "$DO_LAUNCH" -eq 1 ]; then
    step "启动"
    open "$INSTALLED_APP"
    sleep 2
    if pgrep -f "$INSTALLED_APP/Contents/MacOS/$APP_NAME" >/dev/null; then
        echo "已启动，看菜单栏上的 💊 图标"
    else
        warn "进程没起来，可以这样看报错："
        echo "    log show --last 2m --predicate 'process == \"$APP_NAME\"'"
        echo "  ⚠️ 不要用 '$INSTALLED_APP/Contents/MacOS/$APP_NAME' 直接跑二进制来排查——"
        echo "     绕过 LaunchServices 会让系统把这台机器上的应用标记为「通知被拒绝」。要用 open 启动。"
    fi
fi

step "完成"
echo "应用位置: $INSTALLED_APP"
