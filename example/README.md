# Example testbench

## DUT

Provided RTL module `rtl/dut.sv` simply registers input with parametrized signal width.

## Testbench

Provided testbench `tb/tb.sv` does following actions:

* Import DPI functions from VA library.
* Init EAL, configure device.
* Generate randomized input and collect output from FPGA.
* Deinit EAL.

### Defines

| Define | Description |
| ------ | ----------- |
| VA_WORD_LEN | C2H/H2C AXI-Stream TDATA width. Should be equal to `C_DATA_WIDTH` defined in `top.sv` in VA RTL design. |
| TEST_IN_BUS_WORDS | Number of words (with width of `VA_WORD_LEN` bits) that make up DUT design input bus. Total input bus width in bits is `VA_WORD_LEN * TEST_IN_BUS_WORDS`. |
| TEST_OUT_BUS_WORDS | Number of words (with width of `VA_WORD_LEN` bits) that make up DUT design output bus. Total output bus width in bits is `VA_WORD_LEN * TEST_IN_BUS_WORDS`. |
| TEST_BUFF_SIZE | DPDK mbuf size (excluding `RTE_PKTMBUF_HEADROOM`). |
| TEST_BEATS | Total number of clock edges to run in simulation. |
| TEST_DEV_ID | VA PCIe device port ID (if only one device is bound, its port ID is `0` by default). |
| TEST_DEBUG_PRINT | Enable debug printing of input/output values in hexadecimal format in log. |

### Run

> Please notice if `igb_uio` driver is used, simulator should be run as root. Consider using containerization tools like Docker. Other drivers can be used if possible.

1. Instatiate your DUT in VA RTL design.
2. Run synthesis and implementation, program FPGA (reboot host machine if needed).
3. Bind device (`igb_uio` driver example):

```bash
export RTE_SDK="..." # Path to local DPDK install
export FPGA_PF="01:00.0" # FPGA PF ID

modprobe uio
insmod ${RTE_SDK}/dpdk-kmods/linux/igb_uio/igb_uio.ko 

python3 ${RTE_SDK}/usertools/dpdk-devbind.py -b igb_uio ${FPGA_PF}
```

You can get FPGA PF ID from QDMA IP settings (`PF IDs` tab) or using `lspci`:

```bash
$ lspci

# ...
01:00.0 Memory controller: Xilinx Corporation Device 9038
```

Note that VA uses single PF.

4. (*Optional*) check device status:

```bash
python3 ${RTE_SDK}/usertools/dpdk-devbind.py --status
```

You should get following output:

```
Network devices using DPDK-compatible driver
============================================
0000:01:00.0 'Device 9038' drv=igb_uio unused=
```
5. Run provided testbench using any SystemVerilog and DPI-compatible simulator (VCS, Xcelium, Questa):

```bash
# Questa example
# path to SO is specified without .so extension

vlog <path/to/tb>  && \
vsim <tb_module> -batch -sv_lib <path/to/libfpga_va.so> -do "run -all" 
```
