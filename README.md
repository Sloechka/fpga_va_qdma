# FPGA Functional Verification Acceleration

Accelerate your functional verification modelling through FPGA.

Original idea: https://github.com/MPSU/FPGA_VA

Components URLs:

* [Xilinx QDMA Subsystem for PCI Express](https://www.xilinx.com/products/intellectual-property/pcie-qdma.html)
* [DPDK](https://www.dpdk.org) / [Xilinx QDMA PMD driver](https://xilinx.github.io/dma_ip_drivers/master/QDMA/DPDK/html/index.html)

## Host machine configuration

Dependencies:

* `DPDK v.22.11/v.21.11/v.20.11`: 
  * git: https://github.com/DPDK/dpdk
  * docs: http://core.dpdk.org/doc/
* `QDMA DPDK PMD driver v2023.2`:
  * git: https://github.com/Xilinx/dma_ip_drivers
  * docs: https://xilinx.github.io/dma_ip_drivers/master/QDMA/DPDK/html/index.html'

For more information, please refer to [official QDMA PMD installation guide](https://xilinx.github.io/dma_ip_drivers/master/QDMA/DPDK/html/build.html).

### Install NUMA (if missing)

```bash
sudo apt-get install libnuma-dev # Ubuntu
sudo yum install numactl-devel # RedHat/CentOS
```

### Download drivers

Create directory for DPDK installation:

```bash
mkdir <dpdk_path>
```

Clone DPDK using git:

```bash
cd <dpdk_path>
git clone http://dpdk.org/git/dpdk-stable
cd dpdk-stable
git checkout v22.11
git clone git://dpdk.org/dpdk-kmods
```

Clone PMD driver (anywhere):

```bash
git clone git@github.com:Xilinx/dma_ip_drivers.git <pmd_path>
```

Copy net driver from PMD to DPDK installation:

```bash
cp -r <pmd_path>/drivers/net/qdma <dpdk_path>/drivers/net/
```

(*Optional*) enable DPDK debug logs in `<dpdk_path>/config/rte_config.h` by adding:

```c
#define RTE_LIBRTE_QDMA_DEBUG_DRIVER 1
```

Add `qdma` to drivers list `<dpdk_path>/drivers/net/meson.build`:

```py
drivers = [
    ...
    'qdma',
]
```

In `<dpdk_path>/drivers/net/qdma/meson.build`:

```py
cflags += ['-DQDMA_DPDK_22_11']
```

Add Xilinx Vendor IDs in `<dpdk_path>/usertools/dpdk-devbind.py`:

```py
xilinx_qdma_pf = {'Class': '05', 'Vendor': '10ee', 'Device': '9011,9111,9211,9311,9014,9114,9214,9314,9018,9118,9218,9318,901f,911f,921f,931f,9021,9121,9221,9321,9024,9124,9224,9324,9028,9128,9228,9328,902f,912f,922f,932f,9031,9131,9231,9331,9034,9134,9234,9334,9038,9138,9238,9338,903f,913f,923f,933f,9041,9141,9241,9341,9044,9144,9244,9344,9048,9148,9248,9348,b011,b111,b211,b311,b014,b114,b214,b314,b018,b118,b218,b318,b01f,b11f,b21f,b31f,b021,b121,b221,b321,b024,b124,b224,b324,b028,b128,b228,b328,b02f,b12f,b22f,b32f,b031,b131,b231,b331,b034,b134,b234,b334,b038,b138,b238,b338,b03f,b13f,b23f,b33f,b041,b141,b241,b341,b044,b144,b244,b344,b048,b148,b248,b348,b058,b158,b258,b358',
'SVendor': None, 'SDevice': None}
xilinx_qdma_vf = {'Class': '05', 'Vendor': '10ee', 'Device': 'a011,a111,a211,a311,a014,a114,a214,a314,a018,a118,a218,a318,a01f,a11f,a21f,a31f,a021,a121,a221,a321,a024,a124,a224,a324,a028,a128,a228,a328,a02f,a12f,a22f,a32f,a031,a131,a231,a331,a034,a134,a234,a334,a038,a138,a238,a338,a03f,a13f,a23f,a33f,a041,a141,a241,a341,a044,a144,a244,a344,a048,a148,a248,a348,c011,c111,c211,c311,c014,c114,c214,c314,c018,c118,c218,c318,c01f,c11f,c21f,c31f,c021,c121,c221,c321,c024,c124,c224,c324,c028,c128,c228,c328,c02f,c12f,c22f,c32f,c031,c131,c231,c331,c034,c134,c234,c334,c038,c138,c238,c338,c03f,c13f,c23f,c33f,c041,c141,c241,c341,c044,c144,c244,c344,c048,c148,c248,c348,c058,c158,c258,c358',
'SVendor': None, 'SDevice': None}
```

Append following in the same `<dpdk_path>/usertools/dpdk-devbind.py`:

```py
network_devices = [network_class, cavium_pkx, avp_vnic, ifpga_class, xilinx_qdma_pf, xilinx_qdma_vf]
```

### Edit grub configuration

Enable hugepages in `/etc/default/grub`:

```bash
# This is example cmdline, do not override your settings!
GRUB_CMDLINE_LINUX="default_hugepagesz=1GB hugepagesz=1G hugepages=20"
```

This example provides 20 1 GB hugepages which are required to support 2048 queues, with descriptor ring 1024 entries and 4 KB descriptor buffer length. VA do not require this much memory since only two queues (RX/TX) are used. Numbers might be reduced if required.

> (*Optional*) Enable IOMMU if needed (VFs are not used in VA by default):
>
> On an Intel platform, update `/etc/default/grub` file as below:
> 
> ```bash
> GRUB_CMDLINE_LINUX="default_hugepagesz=1GB hugepagesz=1G hugepages=20 iommu=pt intel_iommu=on"
> ```
> 
> On an AMD platform, update `/etc/default/grub` file as below:
> 
> ```bash
> GRUB_CMDLINE_LINUX="default_hugepagesz=1GB hugepagesz=1G hugepages=20 iommu=pt amd_iommu=on"
> ```

Execute the following command to modify the `/boot/grub/grub.cfg` with the configuration set in the above steps and permanently add them to the kernel command line.

```
update-grub
```

Reboot host machine.

### Compile drivers

> Install python / meson / ninja if needed.

Compile DPDK:

```bash
cd <dpdk_path>
meson build
cd build
ninja
sudo ninja install
sudo ldconfig
```

Compbile `igb_uio` driver:

```bash
cd <dpdk_path>/dpdk-kmods/linux/igb_uio
sudo make
```

## Using VA

For further steps please refer to following manuals:

* [VA RTL design](rtl/README.md)
* [C API compilation](api/README.md)
* [Example testbench](example/README.md)