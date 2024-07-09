#ifndef DPI_H
#define DPI_H

#ifdef __cplusplus
#define DPI_LINK_DECL  extern "C" 
#else
#define DPI_LINK_DECL 
#endif

#include "svdpi.h"
#include "va_lib.h"
#include "perf.h"

DPI_LINK_DECL DPI_DLLESPEC
void
dpi_va_init(
    const svOpenArrayHandle args);

DPI_LINK_DECL DPI_DLLESPEC
void
dpi_va_deinit();

DPI_LINK_DECL DPI_DLLESPEC
int
dpi_va_dev_open(
    uint16_t dev_id,
    uint32_t ring_depth,
    uint32_t buff_size);

DPI_LINK_DECL DPI_DLLESPEC
int
dpi_va_dev_close(
    uint16_t dev_id);

DPI_LINK_DECL DPI_DLLESPEC
int
dpi_va_dev_remove(
    uint16_t dev_id);

DPI_LINK_DECL DPI_DLLESPEC
void
dpi_va_dev_step(
    uint16_t dev_id,
    const svBitVecVal* data_in,
    uint32_t data_in_size,
    uint32_t data_out_size,
    svBitVecVal* data_out);

DPI_LINK_DECL DPI_DLLESPEC
void
dpi_perf_start();

DPI_LINK_DECL DPI_DLLESPEC
void
dpi_perf_print_freq(
    uint64_t beats);


#endif // DPI_H
