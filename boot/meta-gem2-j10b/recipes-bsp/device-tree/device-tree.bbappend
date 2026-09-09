FILESEXTRAPATHS:prepend := "${THISDIR}/files:${THISDIR}/../../../artifacts:"

# Keep BOOT manifest SDT provenance aligned with the custom sdt-artifacts
# provider selected by this layer.
SDT_URI = "file://sdt-gem2-j10b.tar.gz"
SDT_URI[sha256sum] = "9e5a9d6a631703cd031a451c6a545a0daced35a2206938f1fbf732fa37faff80"
SDT_URI[S] = "${WORKDIR}/sdt-gem2-j10b"

python __anonymous () {
    machine = d.getVar("MACHINE")
    mc = d.getVar("BB_CURRENT_MC")

    if (machine == "k26-smk-kr-sdt-multidomain" and
            mc == "k26-smk-kr-sdt-multidomain-cortexa53-fsbl"):
        d.appendVar("SRC_URI", " file://0001-k26-kr260-fsbl-assign-gem2-to-a53.patch")
}
