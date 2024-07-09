#ifndef PERF_H
#define PERF_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdio.h>
#include <time.h>

void perf_start();
void perf_print_freq(uint64_t beats);

#ifdef __cplusplus
}
#endif

#endif // VA_LIB_H