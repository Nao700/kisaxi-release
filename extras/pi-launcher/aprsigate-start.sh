#!/bin/bash
# KISAXI をダブルクリックやメニューから起動するためのスクリプト (Linux / Raspberry Pi)
# 実行ファイル (aprsigate-linux-*) と同じフォルダに置いて使う。
# すでに動いている (systemd で常駐中など) ときは、起動せずに管理画面だけを開く。
cd "$(dirname "$(readlink -f "$0")")" || exit 1

URL=http://127.0.0.1:8073/

pause() {
	echo
	read -r -p "Enter キーでこの画面を閉じます" _
}

running() {
	(exec 3<>/dev/tcp/127.0.0.1/8073) 2>/dev/null
}

if running; then
	echo "KISAXI はすでに動いています。管理画面を開きます: $URL"
	xdg-open "$URL" >/dev/null 2>&1 &
	sleep 2
	exit 0
fi

case "$(uname -m)" in
aarch64 | arm64) want=aprsigate-linux-arm64 ;;
armv7l) want=aprsigate-linux-armv7 ;;
armv6l) want=aprsigate-linux-armv6 ;;
x86_64) want=aprsigate-linux-x64 ;;
*) want= ;;
esac

bin=
for f in "$want" aprsigate-linux-* aprsigate; do
	if [ -n "$f" ] && [ -f "$f" ] && [ "${f%.old}" = "$f" ]; then
		bin=$f
		break
	fi
done
if [ -z "$bin" ]; then
	echo "このフォルダ ($PWD) に KISAXI の実行ファイルが見つかりません。"
	echo "この端末に合うファイル: ${want:-不明 ($(uname -m))}"
	pause
	exit 1
fi
[ -x "$bin" ] || chmod +x "$bin"

echo "KISAXI ($bin) を起動します。止めるときはこの画面で Ctrl+C を押すか、画面を閉じます。"
echo
"./$bin" "$@"
code=$?
echo
if [ "$code" -eq 0 ] && sleep 3 && running; then
	echo "更新後の新しい版がバックグラウンドで動いています。この画面は閉じてかまいません。"
else
	echo "KISAXI が終了しました (終了コード $code)。"
fi
pause
