# Force every multiconfig (including the FSBL build) to consume the
# Vivado 2026.1 SDT generated from the Phase 1 GEM2/J10B XSA.
SDT_URI = "file://${LAYERDIR}/../artifacts/sdt-gem2-j10b.tar.gz"
SDT_URI[sha256sum] = "9e5a9d6a631703cd031a451c6a545a0daced35a2206938f1fbf732fa37faff80"
SDT_URI[S] = "${WORKDIR}/sdt-gem2-j10b"
