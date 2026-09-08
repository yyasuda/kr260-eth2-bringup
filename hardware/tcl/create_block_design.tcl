# GEM2/J10B-only adaptation of the Qiita KR260 four-Ethernet design.

namespace eval local {
    proc create_xip_cell {ip name args} {
        set cell [create_bd_cell -type ip -vlnv xilinx.com:ip:$ip $name]
        if {[llength $args] > 0} {
            set_property -dict [lindex $args 0] $cell
        }
        return $cell
    }
    proc connect_pins {pin_a pin_b} {
        connect_bd_net [get_bd_pins $pin_a] [get_bd_pins $pin_b]
    }
    proc connect_ifs {if_a if_b} {
        connect_bd_intf_net [get_bd_intf_pins $if_a] [get_bd_intf_pins $if_b]
    }
    proc make_if_external {bd_if name} {
        make_bd_intf_pins_external [get_bd_intf_pins $bd_if] -name $name
    }
}

set mpsoc [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config {apply_board_preset "1"} $mpsoc
set_property -dict [list \
    CONFIG.PSU__ENET2__GRP_MDIO__ENABLE 1 \
    CONFIG.PSU__ENET2__GRP_MDIO__IO EMIO \
    CONFIG.PSU__ENET2__PERIPHERAL__ENABLE 1 \
    CONFIG.PSU__ENET2__PERIPHERAL__IO EMIO] $mpsoc
local::connect_pins zynq_ultra_ps/pl_clk0 zynq_ultra_ps/maxihpm0_fpd_aclk
local::connect_pins zynq_ultra_ps/pl_clk0 zynq_ultra_ps/maxihpm1_fpd_aclk

set converter [local::create_xip_cell gmii_to_rgmii:4.1 enet2_gmii_to_rgmii [list \
    CONFIG.SupportLevel {Include_Shared_Logic_in_Core}]]
local::connect_ifs enet2_gmii_to_rgmii/MDIO_GEM zynq_ultra_ps/MDIO_ENET2
local::connect_ifs enet2_gmii_to_rgmii/GMII zynq_ultra_ps/GMII_ENET2
local::make_if_external enet2_gmii_to_rgmii/MDIO_PHY MDIO_PL_GEM2_PHY
local::make_if_external enet2_gmii_to_rgmii/RGMII RGMII_PL_GEM2_PHY

set clk_wiz [local::create_xip_cell clk_wiz:6.0 clk_wiz [list \
    CONFIG.CLKOUT1_JITTER 107.361 \
    CONFIG.CLKOUT1_PHASE_ERROR 152.147 \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 375 \
    CONFIG.MMCM_CLKFBOUT_MULT_F 24.375 \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F 3.250 \
    CONFIG.MMCM_DIVCLK_DIVIDE 2 \
    CONFIG.USE_LOCKED false \
    CONFIG.USE_RESET false]]
apply_bd_automation -rule xilinx.com:bd_rule:board \
    -config {Board_Interface {som240_1_connector_hpa_clk0p_clk ( HPA_CLK0P_CLK (som240_1_connector) ) } Manual_Source {Auto}} \
    [get_bd_pins clk_wiz/clk_in1]
local::connect_pins clk_wiz/clk_out1 enet2_gmii_to_rgmii/clkin

create_bd_port -dir O -type rst PL_GEM2_RESETN
set signal_high [local::create_xip_cell xlconstant:1.1 SIGNAL_HIGH]
local::connect_pins SIGNAL_HIGH/Dout PL_GEM2_RESETN

set sys_reset [local::create_xip_cell proc_sys_reset:5.0 sys_reset]
local::connect_pins zynq_ultra_ps/pl_clk0 sys_reset/slowest_sync_clk
local::connect_pins zynq_ultra_ps/pl_resetn0 sys_reset/ext_reset_in
local::connect_pins sys_reset/peripheral_reset enet2_gmii_to_rgmii/tx_reset
local::connect_pins sys_reset/peripheral_reset enet2_gmii_to_rgmii/rx_reset

validate_bd_design
regenerate_bd_layout
save_bd_design

# Fail early if Vivado 2026.1 resolved any key Qiita setting differently.
foreach {description property expected} {
    {GEM2 enable} CONFIG.PSU__ENET2__PERIPHERAL__ENABLE 1
    {GEM2 routing} CONFIG.PSU__ENET2__PERIPHERAL__IO EMIO
    {GEM2 MDIO enable} CONFIG.PSU__ENET2__GRP_MDIO__ENABLE 1
    {GEM2 MDIO routing} CONFIG.PSU__ENET2__GRP_MDIO__IO EMIO
} {
    set actual [get_property $property $mpsoc]
    if {$actual ne $expected} { error "$description: expected $expected, got $actual" }
}
if {[get_property CONFIG.SupportLevel $converter] ne "Include_Shared_Logic_in_Core"} {
    error "GMII-to-RGMII shared-logic configuration mismatch"
}
