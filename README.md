# KR260 GEM2 → J10B (`eth2`) bring-up

AMD Kria KR260 の PS GEM2 を EMIO 経由で PL の GMII-to-RGMII と carrier 上の
DP83867 (U79) に接続し、J10B を Linux の `eth2` として使用するための再現用成果物です。

実機確認済みの到達点（2026-09-08）は次の通りです。

- Ubuntu 24.04.2 LTS / Xilinx kernel 6.8.0-1035-xilinx
- Vivado 2026.1 build 6511674
- K26 Boot FW 1.07 / EDF 26.06 (`amd-edf-rel-v26.06`)
- PHY address 2、PHY ID `0x2000:0xa231`
- `eth2` が `UP,LOWER_UP`、1000 Mb/s、full duplex、auto-negotiation完了
- J10B と外部switch双方のlink LED点灯およびcable挿抜への追従

まだ確認していないのは、外部ホストとの実フレーム双方向疎通です。したがって現時点の
成果は「物理リンク確立まで」であり、IP疎通確認済みとは表現しません。

## 最短の再現方法

書き込み前に必ず [docs/REPRODUCE.ja.md](docs/REPRODUCE.ja.md) を最後まで読み、
既存Boot FWのA/B状態と `/boot/firmware/image.fit` のバックアップを確認してください。
QSPIと共有boot partitionの両方を変更するため、UART consoleと復旧手段なしでの実施は
推奨しません。

配布済み成果物を使う場合は `release/` の2ファイルを使います。

```text
release/BOOT-gem2-j10b.bin
release/image-gem2-j10b.fit
```

ハッシュは `SHA256SUMS` に記録されています。設計をソースから再生成する場合は
[docs/BUILD.ja.md](docs/BUILD.ja.md) を参照してください。

## 構成

```text
hardware/   Vivado block design生成Tcl、XDC、build出力先
boot/       EDF/Yocto layer、FSBL権限patch、Ubuntu FIT生成script
release/    実機でlink-upを確認した組合せの配布用BOOT.BIN/FIT
scripts/    KR260側での事前確認・事後確認script
docs/       buildおよび安全なdeployment手順
```

## 重要な設計条件

元設計は hkato-sssl 氏の「[KR260で4つのEthernet PortをGEMに接続する](https://qiita.com/hkato-sssl/items/ae6129b6da2533b30bb1)」を参照しています。
変更点は以下の通りです。

- OSをPetaLinux 2024.2からUbuntu 24.04.2 LTS（Xilinx kernel 6.8.0-1035-xilinx）へ変更
- Vivadoを2024.2からVivado 2026.1 build 6511674へ変更
- 元設計がPLへ接続するGEM2/J10BとGEM3/J10Aの2系統のうち、GEM2/J10Bだけを実装し、Ubuntuから`eth2`として見えるように変更

`BOOT-gem2-j10b.bin` と `image-gem2-j10b.fit` は一組です。`BOOT-gem2-j10b.bin` には
FSBL、PMUFW、PL design、TF-A、U-Bootなどが含まれます。一方、実際にLinuxへ渡される
Device Treeは、Ubuntuの共有boot partitionにある `image-gem2-j10b.fit` 内にあります。
そのためBOOT.BINだけを更新しても、Linux側ではGEM2/J10Bが有効にならず、`eth2`は生成されません。

また、Ubuntuの `dfx-mgr.service` が有効だと、FSBLがロードしたflat PL designを
`k26-starter-kits` designで上書きし、作成したdesignが無効になります。そのため、このdesignを
機能させるには `dfx-mgr.service` のmaskとcold bootが必須です。

## システム概要

K26 MPSoC内のPS GEM2からGMIIとMDIOをEMIO経由でPLへ出し、PL内の
GMII-to-RGMII IPを介してKR260 carrier上のDP83867 PHY（U79）へ接続します。PHYの
1000BASE-T interfaceはRJ45 connector J10Bへ接続されています。

PL designはBOOT.BINに組み込み、cold boot時にFSBLがconfigurationします。Linux側では
Ubuntu FIT内のDevice TreeにGEM2、GMII-to-RGMII converter（MDIO address 8）、DP83867
（MDIO address 2）を記述し、GEM2/J10Bを `eth2` として使用します。Linux起動後もこの
boot時のPL configurationを維持するため、`dfx-mgr.service`を無効化します。

Ethernet名はKR260のport表記に合わせ、J10D/GEM0を `eth0`、J10C/GEM1を `eth1`、
J10B/GEM2を `eth2` とします。Ubuntuのpredictable network interface namingによる
`end0` などへのrenameを避けるため、`boot/systemd-network/` のpath-based `.link` filesも
配置します。

```text
Ubuntu eth2 / macb (PS GEM2)
             |
          EMIO GMII/MDIO
             |
      PL GMII-to-RGMII
             |
        DP83867 (U79)
             |
          J10B RJ45
```

## 開発環境

- Board: AMD Kria KR260 Robotics Starter Kit、KR260 revB
- FPGA: `xck26-sfvc784-2LV-c`
- Vivado: 2026.1 build 6511674、Board Store KR260 SOM/carrier 2.0
- Boot FW build: AMD EDF 26.06、manifest tag `amd-edf-rel-v26.06`
- Boot FW baseline: K26 Boot FW 1.07
- Target OS: Ubuntu 24.04.2 LTS、kernel 6.8.0-1035-xilinx、AArch64
- Build host: Ubuntu 22.04.5 LTS


## ライセンス

このリポジトリには現時点で包括的なライセンスを設定していません。AMD/Xilinx生成物や
同梱バイナリには各提供元のライセンス条件も適用され得ます。再配布先をpublicにする前に、
利用者側で公開可否と適切なライセンスを確認してください。
