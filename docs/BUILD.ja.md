# ソースからのビルド

## Vivado hardware

Vivado 2026.1とKR260 Board Store 2.0を使用します。

```bash
source /path/to/AMD/2026.1/Vivado/settings64.sh
vivado -mode batch -nolog -nojournal -notrace -source hardware/tcl/build.tcl
sha256sum hardware/artifacts/gem2_j10b.bit hardware/artifacts/gem2_j10b.xsa
```

参照buildではroute完了、DRC 0、setup WNS +0.380 ns、hold WHS +0.014 nsでした。
Vivado生成物はtool versionやhost条件でbyte-identicalにならないことがあるため、ハッシュ差だけ
で失敗とは判定せず、timing、DRC、設計propertyを確認します。

続いて同じ2026.1環境の `sdtgen` でXSAからSystem Device Tree bundleを生成します。

```bash
boot/scripts/generate_sdt_artifact.sh
```

scriptは `hardware/artifacts/gem2_j10b.xsa` を入力とし、board DTS
`zynqmp-smk-k26-reva` を適用した
`hardware/artifacts/sdt-gem2-j10b.tar.gz` を生成します。生成後はbitstream、XSA、SDT bundleを
EDF layerへ配置します。

```bash
install -m 0644 hardware/artifacts/gem2_j10b.bit boot/artifacts/gem2_j10b.bit
install -m 0644 hardware/artifacts/gem2_j10b.xsa boot/artifacts/gem2_j10b.xsa
install -m 0644 hardware/artifacts/sdt-gem2-j10b.tar.gz boot/artifacts/sdt-gem2-j10b.tar.gz
sha256sum boot/artifacts/gem2_j10b.bit boot/artifacts/gem2_j10b.xsa \
  boot/artifacts/sdt-gem2-j10b.tar.gz
```

SDT bundleを更新した場合は、表示されたSHA-256を
`boot/meta-gem2-j10b/recipes-bsp/sdt-artifacts/sdt-artifacts.bbappend` と
`boot/meta-gem2-j10b/recipes-bsp/device-tree/device-tree.bbappend` の
`SDT_URI[sha256sum]` に反映し、rootの `SHA256SUMS` も更新してください。3成果物が同じ
Vivado build由来であることを確認してからEDF buildへ進みます。

## EDF 26.06 Boot FW

AMD EDFの `amd-edf-rel-v26.06` manifestを用意し、リポジトリの
`boot/meta-gem2-j10b` layerを `BBLAYERS` に追加します。layer内の
`sdt-artifacts.bbappend` は上記XSA由来の `boot/artifacts/sdt-gem2-j10b.tar.gz` を使い、
FSBL用DTへGEM2のA53 permission patchを適用します。

```bash
source /path/to/edf/edf-init-build-env build
bitbake-layers add-layer /path/to/this-repo/boot/meta-gem2-j10b
MACHINE=k26-smk-kr-sdt-multidomain bitbake xilinx-bootbin
```

参照BOOT.BINはFSBL、PMUFW、PL bitstream、TF-A、machine DTB、U-Bootの順です。最終imageで
GEM2 (`NODE_ETH_2`, `0xff0d0000`) がA53にshareable resourceとして割り当てられていること、
PL partitionが存在することをdeployment前に確認してください。

## Ubuntu FIT

KR260で現在使用中の既知正常 `image.fit` をhostへコピーします。EDF build treeのnative
`dtc`, `fdtoverlay`, `fdtput`, `dumpimage`を用いてDTだけをmaterializeします。

```bash
EDF_BUILD_DIR=/path/to/edf/build \
  boot/scripts/materialize_ubuntu_fit.sh image.fit.known-good image-gem2-j10b.fit
```

scriptはFIT configurationが使用するrevB DTB（`dumpimage -p 5`）へoverlayを適用し、FDT hashを
更新して `dumpimage -l` で検証します。別Ubuntu imageではFIT内のposition/configurationが
異なる可能性があるため、scriptを盲目的に適用しないでください。

この処理の目的は、Ubuntuがboot時に実際に選ぶDevice TreeへGEM2/J10Bの構成を恒久的に
組み込むことです。BOOT.BIN内にもmachine DTBはありますが、このUbuntu環境ではU-Bootの
boot scriptが `/boot/firmware/image.fit` 内のrevB DTBをLinuxへ渡します。そのため、PL designを
含むBOOT.BINの作成とは別に、FIT内DTBのGEM2有効化とhash更新が必要です。
