# Qiita GEM2/J10B pin assignment, mechanically checked against the
# Vivado 2026.1 KR260 carrier 2.0 and SOM 2.0 Board Store definitions.

set_property IOSTANDARD LVCMOS18 [get_ports MDIO_PL_GEM2_PHY_mdc]
set_property IOSTANDARD LVCMOS18 [get_ports MDIO_PL_GEM2_PHY_mdio_io]
set_property IOSTANDARD LVCMOS18 [get_ports RGMII_PL_GEM2_PHY_rx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports RGMII_PL_GEM2_PHY_rxc]
set_property IOSTANDARD LVCMOS18 [get_ports RGMII_PL_GEM2_PHY_tx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports RGMII_PL_GEM2_PHY_txc]
set_property IOSTANDARD LVCMOS18 [get_ports {RGMII_PL_GEM2_PHY_rd[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {RGMII_PL_GEM2_PHY_td[*]}]

set_property PACKAGE_PIN A1 [get_ports {RGMII_PL_GEM2_PHY_rd[0]}]
set_property PACKAGE_PIN B3 [get_ports {RGMII_PL_GEM2_PHY_rd[1]}]
set_property PACKAGE_PIN A3 [get_ports {RGMII_PL_GEM2_PHY_rd[2]}]
set_property PACKAGE_PIN B4 [get_ports {RGMII_PL_GEM2_PHY_rd[3]}]
set_property PACKAGE_PIN E1 [get_ports {RGMII_PL_GEM2_PHY_td[0]}]
set_property PACKAGE_PIN D1 [get_ports {RGMII_PL_GEM2_PHY_td[1]}]
set_property PACKAGE_PIN F2 [get_ports {RGMII_PL_GEM2_PHY_td[2]}]
set_property PACKAGE_PIN E2 [get_ports {RGMII_PL_GEM2_PHY_td[3]}]
set_property PACKAGE_PIN A4 [get_ports RGMII_PL_GEM2_PHY_rx_ctl]
set_property PACKAGE_PIN F1 [get_ports RGMII_PL_GEM2_PHY_tx_ctl]
set_property PACKAGE_PIN A2 [get_ports RGMII_PL_GEM2_PHY_txc]
set_property PACKAGE_PIN D4 [get_ports RGMII_PL_GEM2_PHY_rxc]
set_property PACKAGE_PIN G3 [get_ports MDIO_PL_GEM2_PHY_mdc]
set_property PACKAGE_PIN F3 [get_ports MDIO_PL_GEM2_PHY_mdio_io]
set_property SLEW SLOW [get_ports MDIO_PL_GEM2_PHY_mdc]
set_property SLEW SLOW [get_ports MDIO_PL_GEM2_PHY_mdio_io]

set_property PACKAGE_PIN B1 [get_ports PL_GEM2_RESETN]
set_property IOSTANDARD LVCMOS18 [get_ports PL_GEM2_RESETN]

# Vivado 2026.1 otherwise treats the protocol-asynchronous MDIO return path as
# a synchronous clk_out1-to-MDC transfer.  Limit the exception to the PS GEM2
# MDIO input endpoint; all RGMII data and clock paths remain timed.
set_false_path -to [get_pins -hier -filter {NAME =~ */PS8_i/EMIOENET2MDIOI}]
