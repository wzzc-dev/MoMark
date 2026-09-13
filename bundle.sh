#!/usr/bin/env bash
# 把 macos_skia 可执行文件包进最小 macOS .app（产品名 MoMark）。
#
# 裸 Mach-O 不配作为前台 GUI 应用：macOS 不会向它投递键盘事件，编辑器的键入
# 会全部丢失（GpMark 有同样的记录，见 gpmark/bundle.sh）。带 Info.plist 的
# bundle 修复这一点；直接运行 Contents/MacOS/MoMark 仍继承 bundle 身份并保留
# 终端 stdout/stderr，便于按文件启动与调试：
#
#   ./dist/MoMark.app/Contents/MacOS/MoMark path/to/document.md
#
# 产物名与内部包名有意分开：`momark` 是 MoonBit 模块 id，改名会牵动 workspace
# 成员、import 与发布脚本；用户看到的只有 bundle 名与发行包名，统一叫 MoMark。
#
# 用法：bundle.sh [可执行文件路径]
# 不传路径时按 release → debug、模块内 `_build` → 上层 workspace `_build` 的顺序
# 查找。两种布局都支持是因为独立 checkout 的产物落在模块内，而 md_editor 根
# moon.work 把整个 workspace 的产物放在仓库根的 `_build`。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PRODUCT="MoMark"
APP="$ROOT/dist/$PRODUCT.app"
RELATIVE_EXE="_build/native/%s/build/wzzc-dev/momark/macos_skia/macos_skia.exe"

EXE="${1:-}"
if [ -z "$EXE" ]; then
  for profile in release debug; do
    for base in "$ROOT" "$ROOT/.."; do
      candidate="$base/$(printf "$RELATIVE_EXE" "$profile")"
      if [ -f "$candidate" ]; then
        EXE="$candidate"
        break 2
      fi
    done
  done
fi
if [ -z "$EXE" ] || [ ! -f "$EXE" ]; then
  echo "未找到 macos_skia 可执行文件 — 先运行：moon build momark/macos_skia --target native [--release]" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$EXE" "$APP/Contents/MacOS/$PRODUCT"
chmod +x "$APP/Contents/MacOS/$PRODUCT"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$PRODUCT</string>
  <key>CFBundleDisplayName</key><string>MoMark — Markdown Editor</string>
  <key>CFBundleIdentifier</key><string>dev.local.momark.editor</string>
  <key>CFBundleVersion</key><string>0.1.0</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleExecutable</key><string>$PRODUCT</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST

echo "打包完成: $APP"
echo "GUI 启动:   open '$APP'"
echo "按文件启动: open '$APP' --args /path/to/document.md"
echo "带终端输出: '$APP/Contents/MacOS/$PRODUCT' [/path/to/document.md]"
