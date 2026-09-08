# 実機への再現手順

## 1. 前提と安全条件

対象は KR260 revB、Ubuntu 24.04.2、K26 Boot FW 1.07を基準としています。異なるcarrier、
OS、boot script、FIT構成ではそのまま適用しないでください。UARTを115200 8N1で接続し、
既知正常なBoot FW slotを最低1つ残します。

### K26 Boot FW 1.07の入手について

手元のKR260に搭載されていたBoot Firmwareはかなり古い世代のものでした。この古い
firmwareを直接解析・改造するのではなく、現在のAMD/Xilinxの開発環境に近いBoot Firmwareを
基準とし、必要な変更だけを加える方針としました。

Kria Starter KitのBoot Firmwareは、世代によって生成方式が変化しています。古い世代は
PetaLinuxベースでしたが、その後Yoctoベースの生成方式へ移行し、さらに新しい世代では
SDT（System Device Tree）flowとAMD EDF（Embedded Development Framework）を使用する
構成になっています。調査時点で公開されていたKR260 Boot FW 1.07は、この新しい
Yocto / SDT / EDF系のBoot Firmwareです。

AMD Adaptive Computing Wikiの「[Kria SOMs & Starter Kits](https://xilinx-wiki.atlassian.net/wiki/pages/viewpage.action?pageId=4035837953)」では、KR260 Boot FW 1.07は
次のBoot Firmwareとして掲載されています。

- KR260 Robotics Starter Kit用
- componentsを2026.1へ更新
- KR260のflat support
- Yocto-generated
- EDF distro
- semantic versioning

掲載されているversion stringは次の通りです。

```text
k26-smk-kr-sdt-v1.07-20260610204217
```

作業開始時、必要な2026.1世代のBoot Firmware関連データに対するAMDの通常のWeb/download
ページのリンクは切れていました。一方、上記Wikiページには正しいAMD Download Centerの
[認証付きdownload link](https://account.amd.com/en/forms/downloads/xef.html?filename=BOOT-k26-smk-kr-sdt-multidomain-20260609231841.bin)があり、そこから次のファイルを入手できました。

```text
BOOT-k26-smk-kr-sdt-multidomain-20260609231841.bin
size:    1,935,432 bytes
SHA-256: 152f026f9ec0288e7231053d9ea1bca1dd48bcbc7a2e392918e8514bc115c40f
MD5:     ac00ec5416f6f5a7b079f089d17b37a7
```

このdownload linkの利用にはAMDアカウントによる認証が必要です。入手したファイルの
checksumがAMD公開物と一致することも確認済みです。

custom Boot FWのソース側は、AMD/Xilinxの `yocto-manifests` にあるEDF 26.06 tag
`amd-edf-rel-v26.06`を使用しています。patch適用前の標準buildが上記AMD配布バイナリと
byte-for-byteで一致したことを確認済みです。本リポジトリの配布済みBOOT.BINを使うだけなら、
元の1.07バイナリを別途入手する必要はありません。

次をKR260側で実行し、結果を保存します。

```bash
set -o pipefail
sudo ./scripts/preflight.sh | tee preflight-before.txt
```

以下を満たさない場合は中止します。

- `Image A` と `Image B` がともに `Bootable`
- 現在の `Last Booted Image` が判明している
- `/boot/firmware` がmountされ、`image.fit` が存在する
- `release/` のハッシュが `SHA256SUMS` と一致する
- UART consoleからboot失敗を観測・復旧できる

scriptはBoot FW A/B、Last Booted Image、boot partitionと `image.fit` を自動判定し、条件を
満たさなければ非0で終了します。UART consoleと復旧手段は自動判定できないため、作業者が
確認します。配布物のハッシュは次節で転送前後に別途確認します。

Boot FWのinactive slotへの更新は既知正常slotを残せる場合だけ行います。`image.fit` はA/B
slot別ではなく、両slotから共有される `/boot/firmware` 上のファイルです。

## 2. ファイルをKR260へ転送

ホスト側でリポジトリrootから実行します（hostname/IPは環境に合わせます）。

```bash
sha256sum -c SHA256SUMS
scp release/BOOT-gem2-j10b.bin ubuntu@KR260:/tmp/
scp release/image-gem2-j10b.fit ubuntu@KR260:/tmp/
```

KR260側でも照合します。

```bash
sha256sum /tmp/BOOT-gem2-j10b.bin /tmp/image-gem2-j10b.fit
```

期待値は `SHA256SUMS` と一致する必要があります。

## 3. 共有FITのバックアップと置換

`image.fit` は共有boot partition上にあるため、先に一意な名前でバックアップします。

```bash
stamp=$(date -u +%Y%m%dT%H%M%SZ)
sudo cp -a /boot/firmware/image.fit "/boot/firmware/image.fit.backup-${stamp}"
sha256sum /boot/firmware/image.fit "/boot/firmware/image.fit.backup-${stamp}"
sudo cp /tmp/image-gem2-j10b.fit /boot/firmware/image.fit.new
sudo sync
sha256sum /boot/firmware/image.fit.new
sudo mv /boot/firmware/image.fit.new /boot/firmware/image.fit
sudo sync
sha256sum /boot/firmware/image.fit
```

## 4. dfx-mgrによるflat PL designの上書きを抑止する

KR260の標準Ubuntu環境には `dfx-mgr` serviceが用意されており、`xmutil loadapp`を使って
現在のaccelerated applicationを確認したり、cold bootせずにPL designを動的に入れ替えたり
できます。開発時には、これとは別に `devmem`でregisterを一時的に変更するような診断も可能です。

一方、このリポジトリではfull bitstreamをBOOT.BINへ組み込み、cold boot時にFSBLがPL全体を
configurationする固定的な構成（flat PL design）を使用します。標準の `dfx-mgr`を動かしたままに
すると、Linux起動後に別のdesignがPLへロードされ、boot時のdesignが上書きされます。
これを防ぐため、Ubuntu起動後に `dfx-mgr`がPLを上書きしないようserviceをmaskします。

```bash
sudo systemctl mask dfx-mgr.service
systemctl is-enabled dfx-mgr.service
```

出力が `masked` であることを確認します。

## 5. inactive Boot FW slotへ書く

直前にもう一度 `sudo xmutil bootfw_status` を確認します。次のコマンドはinactive imageを
更新し、次回boot対象にします。

```bash
sudo xmutil bootfw_update -i /tmp/BOOT-gem2-j10b.bin
sudo xmutil bootfw_status
```

新しいimageが `Requested Boot Image` かつ `Non Bootable`、既知正常imageが `Bootable`
のままであることを確認します。ここで `xmutil bootfw_update -v` はまだ実行しません。

## 6. UART監視下でcold boot

warm rebootではなく電源を完全に切ってから再投入します。UARTでFSBL、PMUFW、TF-A、
U-Boot、Linux loginまで進むことを確認します。ログイン後に実行します。

```bash
set -o pipefail
sudo ./scripts/verify-eth2.sh | tee eth2-after.txt
```

合格条件は次です。

- `dfx-mgr.service`: `masked` / `inactive`
- `eth2`: `LOWER_UP`
- `ethtool eth2`: 1000Mb/s、Full、PHYAD 2、Link detected yes
- J10Bとpeer双方のlink LEDが点灯し、cable挿抜に追従

scriptはservice状態、`LOWER_UP`、speed、duplex、PHYAD、link状態を自動判定し、条件を
満たさなければ非0で終了します。LEDとcable挿抜への追従は作業者が確認します。

筆者の環境では、調査中に一度だけJ10BのPHYが通常のMDIO address 2ではなくaddress 13で
見えたことがありました。trouble時には `mdio-tools`を別途導入し、PHY@2のID registerが
`0x2000` / `0xa231`であることを確認すると切り分けに役立つ可能性があります。この事例では
PHY@2から値を読み出せず、同じIDがPHY@13から読み出されましたが、その次のclean cold bootで
PHYは再びaddress 2へ戻りました。開発中の変則的な操作による一時状態だったのか、別の原因
だったのかは特定できていません。そのためaddress 13を通常設定として使用しないでください。

bootと基本動作を確認して初めて、trial imageをBootableにします。

```bash
sudo xmutil bootfw_update -v
sudo xmutil bootfw_status
```

## 7. 双方向フレーム確認（未完了項目）

外部Linux hostとJ10Bを接続し、別subnetの固定IPを仮設定します。

```bash
# KR260
sudo ip addr add 192.0.2.2/24 dev eth2
sudo ip link set eth2 up

# peer（interface名は置換）
sudo ip addr add 192.0.2.1/24 dev PEER_IF
sudo tcpdump -ni PEER_IF 'arp or icmp'
ping -c 4 192.0.2.2
```

KR260側でも `sudo tcpdump -ni eth2 'arp or icmp'` を動かし、ARP/ICMPを両方向で確認します。
`192.0.2.0/24` は文書用アドレスですが、既存routeと競合する場合は別のisolated subnetを
選びます。

## 復旧

trial bootが失敗した場合は既知正常slotへfallbackさせ、UARTログを保存します。Linuxまで
起動できるがnetworkだけ失敗した場合は、保存した `image.fit.backup-*` を
`/boot/firmware/image.fit` に戻し、`sync`後にcold bootします。slot選択を推測で操作したり、
`fw_setenv` を使ったりしないでください。
