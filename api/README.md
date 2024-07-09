# C API documentation

## Functions

### va_init

```c
void va_init(int argc, char *argv[])
```

| Argument | Type | Default | Description |
| -------- | ---- | ------- | ----------- |
| `argc` | `int` | **required** | Number of arguments (including program name) |
| `argv` | `char**` | **required** | String arguments |

This function initializes EAL and checks for available devices as simple sanity-check. This function should be called before other functions.

`argc` and `argv` should be passed as in normal program, including program name as first argument. These arguments are passed directly to `rte_eal_init()` function.

Example:

```c
int test_argc = 5;
char *test_argv[] = {
    "va_tb",
    "-c", "0xf",
    "-n", "4"
};

va_init(test_argc, test_argv);
```

### va_deinit

```c
void va_deinit()
```

Deinitializes EAL and performs cleanup.

### va_dev_open

```c
int va_dev_open(uint16_t dev_id, uint32_t ring_depth, uint32_t buff_size);
```

| Argument | Type | Default | Description |
| -------- | ---- | ------- | ----------- |
| `dev_id` | `uint16_t` | **required** | FPGA device (port) ID. If only single device is bound, it has ID = `0` by default |
| `ring_depth` | `uint32_t` | **required** | DPDK mbuf pool depth. Total number of elements in pool is `ring_depth * <number of queues>` |
| `buff_size` | `uint32_t` | **required** | Size of data buffer in each mbuf, excluding RTE_PKTMBUF_HEADROOM |

| Returns | Description |
| ------- | ----------- |
| `0` | Normal init |
| `-1` | Device with given `dev_id` is already removed or does not exist |

Initializes device for future use. Should be used after EAL initialization and before any interaction.

Ring depth is usually a power of two.

### va_dev_close

```c
int va_dev_close(uint16_t dev_id);
```

| Argument | Type | Default | Description |
| -------- | ---- | ------- | ----------- |
| `dev_id` | `uint16_t` | **required** | FPGA device (port) ID. If only single device is bound, it has ID = `0` by default |

| Returns | Description |
| ------- | ----------- |
| `0` | Normal close |
| `-1` | Device with given `dev_id` is already removed or does not exist |

This command frees up all the allocated resources and removes the queues associated with the port. Device can again be re-initialized with `va_dev_open()` command.

### va_dev_remove

```c
int va_dev_close(uint16_t dev_id);
```

| Argument | Type | Default | Description |
| -------- | ---- | ------- | ----------- |
| `dev_id` | `uint16_t` | **required** | FPGA device (port) ID. If only single device is bound, it has ID = `0` by default |

| Returns | Description |
| ------- | ----------- |
| `0` | Normal remove |
| `-1` | Device with given `dev_id` is already removed or does not exist |

This command frees up all the resources allocated for the port and removes the port from application use. User will need to restart the application to use the port again.

### va_dev_xmit

```c
int va_xmit(uint16_t dev_id, uint8_t *data, uint32_t len);
```

| Argument | Type | Default | Description |
| -------- | ---- | ------- | ----------- |
| `dev_id` | `uint16_t` | **required** | FPGA device (port) ID. If only single device is bound, it has ID = `0` by default |
| `data` | `uint8_t*` | **required** | Pointer to raw data buffer to be transmitted |
| `len` | `uint32_t` | **required** | Buffer length (in bytes)  |

| Returns | Description |
| ------- | ----------- |
| `0` | Normal init |
| `-1` | Device with given `dev_id` is already removed or does not exist; or transmission failed |

This command is used to DMA the data from host to card.

### va_dev_recv

```c
int va_recv(uint16_t dev_id, uint8_t *data, uint32_t len);
```

| Argument | Type | Default | Description |
| -------- | ---- | ------- | ----------- |
| `dev_id` | `uint16_t` | **required** | FPGA device (port) ID. If only single device is bound, it has ID = `0` by default |
| `data` | `uint8_t*` | **required** | Pointer to raw data buffer to store read data |
| `len` | `uint32_t` | **required** | Buffer length (in bytes)  |

| Returns | Description |
| ------- | ----------- |
| `0` | Normal init |
| `-1` | Device with given `dev_id` is already removed or does not exist; or transmission failed |

This command is used to DMA the data from card to host.

## DPI wrapper

Library provides SystemVerilog DPI-compatible functions and stubs in `dpi.c` and `dpi.h` to be used in SV testbenches.

| Function | Description |
| -------- | ----------- |
| `dpi_va_init(const svOpenArrayHandle args)` | Accepts array of strings (`string args[] = { ... }`) |
| `dpi_va_deinit()` | Stub equal to `va_deinit` |
| `dpi_va_dev_open(uint16_t dev_id, uint32_t ring_depth, uint32_t buff_size)` | Stub equal to `va_dev_open` |
| `dpi_va_dev_close(uint16_t dev_id)` | Stub equal to `va_dev_close` |
| `dpi_va_dev_remove(uint16_t dev_id)` | Stub equal to `va_dev_remove` |
| `dpi_va_dev_step(uint16_t dev_id, const svBitVecVal* data_in, uint32_t data_in_size, uint32_t data_out_size, svBitVecVal* data_out);` | Calls `va_xmit` and `va_recv` using given SV bit arrays with known size |

### Perfomance functions

| Function | Description |
| -------- | ----------- |
| `dpi_perf_start()` | Start timer |
| `dpi_perf_print_freq(uint64_t beats)` | Print (stdout) current time and estimated frequency. `beats` is number of clock edges |
