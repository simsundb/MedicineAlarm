#!/bin/bash
#
# 停用旧版 Python 吃药提醒（~/Downloads/06.ai/05.claude/medicine_alarm.py）。
#
# 那个版本的 LaunchAgent 现在是「已加载但每次启动都失败」的状态
# （launchctl 里显示退出码 2），留着它会一直尝试拉起并失败。
#
# 本脚本只做两件事：
#   1. 把旧文件备份到本项目的 .backup/ 目录
#   2. 卸载并移除那个开机自启项
#
# 不会删除 ~/Downloads 下的原脚本和 ~/.medicine_alarm/ —— 它们原地保留。
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$ROOT/.backup"
LEGACY_LABEL="com.medicine-alarm"
LEGACY_PLIST="$HOME/Library/LaunchAgents/$LEGACY_LABEL.plist"
LEGACY_SCRIPT="$HOME/Downloads/06.ai/05.claude/medicine_alarm.py"
LEGACY_CONFIG_DIR="$HOME/.medicine_alarm"

step() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }

step "备份到 $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

[ -f "$LEGACY_PLIST" ]      && cp "$LEGACY_PLIST" "$BACKUP_DIR/"      && echo "  已备份 LaunchAgent"
[ -f "$LEGACY_SCRIPT" ]     && cp "$LEGACY_SCRIPT" "$BACKUP_DIR/"     && echo "  已备份 medicine_alarm.py"
[ -f "$LEGACY_CONFIG_DIR/config.json" ] \
    && cp "$LEGACY_CONFIG_DIR/config.json" "$BACKUP_DIR/legacy-config.json" \
    && echo "  已备份 config.json"

step "卸载旧的开机自启项"
if launchctl list 2>/dev/null | grep -q "$LEGACY_LABEL"; then
    launchctl bootout "gui/$(id -u)/$LEGACY_LABEL" 2>/dev/null \
        || launchctl unload "$LEGACY_PLIST" 2>/dev/null \
        || true
    echo "  已卸载 $LEGACY_LABEL"
else
    echo "  $LEGACY_LABEL 本来就没在运行"
fi

if [ -f "$LEGACY_PLIST" ]; then
    rm -f "$LEGACY_PLIST"
    echo "  已移除 $LEGACY_PLIST"
fi

step "确认"
if launchctl list 2>/dev/null | grep -q "$LEGACY_LABEL"; then
    echo "  ⚠️  旧自启项仍在列表里，可能需要注销后重新登录"
else
    echo "  ✅ 旧自启项已清除"
fi

echo
echo "原文件仍在原处（未删除）："
echo "  $LEGACY_SCRIPT"
echo "  $LEGACY_CONFIG_DIR/"
echo "备份副本在：$BACKUP_DIR"
