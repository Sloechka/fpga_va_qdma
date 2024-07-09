#include "dpi.h"

DPI_LINK_DECL DPI_DLLESPEC
void dpi_va_init(const svOpenArrayHandle args) {
    char **argv;

    int argc = svSize(args, 1);
    argv = (char**)malloc(sizeof(char*) * argc);

    if(argv == NULL) {
        rte_exit(EXIT_FAILURE, "%s: malloc() failed\n", __func__);
    }

    for(int i = 0; i < argc; i++) {
        argv[i] = strdup(*(char**)svGetArrElemPtr1(args, i));

        if(argv[i] == NULL) {
            rte_exit(EXIT_FAILURE, "%s: strdup() failed\n", __func__);
        }
    }

    va_init(argc, argv);
}

DPI_LINK_DECL DPI_DLLESPEC
void dpi_va_dev_step(
    uint16_t dev_id,
    const svBitVecVal* data_in, 
    uint32_t data_in_size, 
    uint32_t data_out_size, 
    svBitVecVal* data_out
) {
    va_xmit(dev_id, (uint8_t*)data_in, data_in_size);
    va_recv(dev_id, (uint8_t*)data_out, data_out_size);
}


// Compatability stubs

DPI_LINK_DECL DPI_DLLESPEC
void dpi_va_deinit() {
    va_deinit();
}

DPI_LINK_DECL DPI_DLLESPEC
int dpi_va_dev_open(uint16_t dev_id, uint32_t ring_depth, uint32_t buff_size) {
    return va_dev_open(dev_id, ring_depth, buff_size);
}

DPI_LINK_DECL DPI_DLLESPEC
int dpi_va_dev_close(uint16_t dev_id) {
    return va_dev_close(dev_id);
}

DPI_LINK_DECL DPI_DLLESPEC
int dpi_va_dev_remove(uint16_t dev_id) {
    return va_dev_remove(dev_id);
}

DPI_LINK_DECL DPI_DLLESPEC
void dpi_perf_start() {
    perf_start();
}

DPI_LINK_DECL DPI_DLLESPEC
void dpi_perf_print_freq(uint64_t beats) {
    perf_print_freq(beats);
}
