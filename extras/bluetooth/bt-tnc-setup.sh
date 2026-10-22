#!/bin/bash
# Bluetooth の無線機 (TH-D74 / TH-D75 / TM-D750) を /dev/rfcommN として使えるようにする。
# ペアリング済みの無線機を探し、シリアルポート (SPP) のチャンネルを調べて
# rfcomm を bind し、起動時にも bind する systemd サービスを登録する。
#
# 使い方: sudo ./bt-tnc-setup.sh [番号]      (番号の既定は 0 → /dev/rfcomm0)
#         sudo ./bt-tnc-setup.sh --remove [番号]
set -eu

RADIOS='TH-D74|TH-D75|TM-D750'

die() { echo "エラー: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "sudo を付けて実行してください (例: sudo $0)"

if [ "${1:-}" = "--remove" ]; then
	n="${2:-0}"
	systemctl disable --now "rfcomm$n.service" 2>/dev/null || true
	rm -f "/etc/systemd/system/rfcomm$n.service"
	rfcomm release "$n" 2>/dev/null || true
	systemctl daemon-reload
	echo "/dev/rfcomm$n の設定を削除しました"
	exit 0
fi

n="${1:-0}"
case "$n" in *[!0-9]* | '') die "番号は数字で指定してください" ;; esac

command -v bluetoothctl >/dev/null || die "bluetoothctl がありません (sudo apt install bluez)"
command -v rfcomm >/dev/null || die "rfcomm コマンドがありません (sudo apt install bluez)"

# ペアリング済みの機器から対応無線機を探す (BlueZ のバージョンでコマンド名が違う)
paired=$(bluetoothctl devices Paired 2>/dev/null || true)
[ -n "$paired" ] || paired=$(bluetoothctl paired-devices 2>/dev/null || true)
mapfile -t found < <(printf '%s\n' "$paired" | grep -E "^Device [0-9A-F:]{17} .*($RADIOS)" || true)

case ${#found[@]} in
0)
	echo "ペアリング済みの TH-D74 / TH-D75 / TM-D750 が見つかりません。"
	echo "無線機の Bluetooth をオンにして、先に bluetoothctl でペアリングしてください:"
	echo "  bluetoothctl → scan on → pair <MAC> → trust <MAC> → quit"
	exit 1
	;;
1)
	sel=${found[0]}
	;;
*)
	echo "対応する無線機が複数見つかりました:"
	for i in "${!found[@]}"; do echo "  $((i + 1))) ${found[$i]#Device }"; done
	read -rp "使う無線機の番号: " k
	case "$k" in *[!0-9]* | '') die "番号が正しくありません" ;; esac
	[ "$k" -ge 1 ] && [ "$k" -le ${#found[@]} ] || die "番号が正しくありません"
	sel=${found[$((k - 1))]}
	;;
esac
mac=$(echo "$sel" | awk '{print $2}')
name=$(echo "$sel" | cut -d' ' -f3-)
echo "無線機: $name ($mac)"

# 再起動後に自動で再接続できるよう信頼済みにする
bluetoothctl trust "$mac" >/dev/null 2>&1 || true

# SPP (Serial Port) のチャンネルを調べる。無線機の電源と Bluetooth が入っている必要がある
ch=""
if command -v sdptool >/dev/null; then
	ch=$(sdptool browse "$mac" 2>/dev/null | awk '
		/^Service RecHandle:/ { sp = 0 }
		/"Serial Port" \(0x1101\)/ { sp = 1 }
		sp && /Channel:/ { print $2; exit }')
fi
if [ -z "$ch" ]; then
	echo "シリアルポートのチャンネルを自動で調べられませんでした。"
	echo "(無線機の電源と Bluetooth がオンになっているか確かめてください。TM-D750 は 27 でした)"
	read -rp "チャンネル番号: " ch
	case "$ch" in *[!0-9]* | '') die "チャンネル番号が正しくありません" ;; esac
fi
echo "チャンネル: $ch"

unit=/etc/systemd/system/rfcomm$n.service
cat >"$unit" <<EOF
[Unit]
Description=rfcomm$n for $name
After=bluetooth.service
Wants=bluetooth.service
Before=aprsigate.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=-/usr/bin/rfcomm release $n
ExecStart=/usr/bin/rfcomm bind $n $mac $ch
ExecStop=/usr/bin/rfcomm release $n

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "rfcomm$n.service" >/dev/null 2>&1
systemctl restart "rfcomm$n.service"

[ -e "/dev/rfcomm$n" ] || die "/dev/rfcomm$n を作れませんでした (journalctl -u rfcomm$n で確認してください)"

echo
echo "/dev/rfcomm$n を作りました ($unit を登録したので再起動後も使えます)。"
echo "KISAXI の設定で TNC を「KISS シリアル」、ポートを /dev/rfcomm$n にして「保存して適用」を押してください。"
echo "無線機側は KISS モードにして、データの通信先を Bluetooth にしてください。"
u=${SUDO_USER:-}
if [ -n "$u" ] && ! id -nG "$u" | grep -qw dialout; then
	usermod -aG dialout "$u"
	echo "$u を dialout グループに追加しました。KISAXI を再起動 (またはログインし直し) してください。"
fi
