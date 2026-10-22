#!/bin/bash
# KISAXI の起動アイコンをデスクトップとアプリケーションメニューに作る (Linux / Raspberry Pi)
# 実行ファイル (aprsigate-linux-*) と aprsigate-start.sh と同じフォルダに置いて、
# 一度だけ `bash desktop-setup.sh` を実行する。sudo は不要。
# 消すときは `bash desktop-setup.sh --remove`
set -e
dir=$(dirname "$(readlink -f "$0")")
desktop=$(xdg-user-dir DESKTOP 2>/dev/null || true)
[ -n "$desktop" ] && [ "$desktop" != "$HOME" ] || desktop=$HOME/Desktop
apps=$HOME/.local/share/applications
name=kisaxi.desktop

if [ "$1" = "--remove" ]; then
	rm -f "$desktop/$name" "$apps/$name"
	echo "起動アイコンを消しました"
	exit 0
fi

if [ ! -f "$dir/aprsigate-start.sh" ]; then
	echo "$dir に aprsigate-start.sh がありません。同じフォルダに置いてから実行してください。" >&2
	exit 1
fi
chmod +x "$dir/aprsigate-start.sh"

icon=utilities-terminal
for f in "$dir/kisaxi_app_icon.png" "$dir/../assets/kisaxi_app_icon.png"; do
	if [ -f "$f" ]; then
		icon=$(readlink -f "$f")
		break
	fi
done

mkdir -p "$desktop" "$apps"
for out in "$desktop/$name" "$apps/$name"; do
	cat >"$out" <<DESKTOP
[Desktop Entry]
Type=Application
Name=KISAXI
Comment=APRS I-Gate を起動して管理画面を開く
Exec="$dir/aprsigate-start.sh"
Path=$dir
Icon=$icon
Terminal=true
Categories=Network;HamRadio;
DESKTOP
	chmod +x "$out"
done
# GNOME 系のデスクトップで「信頼する」扱いにする (使えない環境では何もしない)
gio set "$desktop/$name" metadata::trusted true 2>/dev/null || true

echo "起動アイコンを作りました:"
echo "  デスクトップ: $desktop/$name"
echo "  メニュー:     $apps/$name (「インターネット」の中に KISAXI が出ます)"
