# VA RTL design

## Requirements

* [AMD Kintex UltraScale+ FPGA KCU116 Evaluation Kit](https://www.xilinx.com/products/boards-and-kits/ek-u1-kcu116-g.html) or any other QDMA-compatible FPGA (project .tcl script should be edited in this case);
* [Vivado Design Suite](https://www.xilinx.com/products/design-tools/vivado.html); current project was built and tested in `2023.1`

## RTL

Here are two projects:

* `rtl/` normal FPGA VA IP module;
* `rtl_lbpk` debug QDMA loobpack module.

## Build

### Using TCL script

Execute Vivado in batch mode to generate Vivado project in this folder:

```bash
vivado -mode batch -source fpga_va_qdma_kcu116.tcl
```

To create project in different directory, execute following:

```bash
mkdir -p projects
cd projects
vivado -mode batch -source <path_to_this_repository>/rtl/fpga_va_qdma_kcu116.tcl -tclargs [ --origin_dir "<path_to_this_repository>/rtl/" ]
```

### Manual

* Create Vivado project, choose QDMA-compatible FPGA
* Add sources from this repository:
  * Design sources: `rtl/`
  * Constraints: `xdc/`
* Execute following tcl command:
  
```tcl
create_ip -name qdma -vendor xilinx.com -library ip -version 5.0 -module_name qdma_0

set_property -dict [list \
  CONFIG.dma_intf_sel_qdma {AXI_Stream_with_Completion} \
  CONFIG.mode_selection {Advanced} \
  CONFIG.pl_link_cap_max_link_width {X8} \
] [get_ips qdma_0]
```