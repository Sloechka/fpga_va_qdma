#ifdef __cplusplus
extern "C" {
#endif

#include "perf.h"

struct timespec start, current_timestamp;

int64_t difftimespec_ns(const struct timespec after, const struct timespec before)
{
    return ((int64_t)after.tv_sec - (int64_t)before.tv_sec) * (int64_t)1000000000
         + ((int64_t)after.tv_nsec - (int64_t)before.tv_nsec);
}

void perf_start() {
    clock_gettime(CLOCK_MONOTONIC, &start);
}

void perf_print_freq(uint64_t beats) {
    double delta_s, freq;

    clock_gettime(CLOCK_MONOTONIC, &current_timestamp);

    delta_s = difftimespec_ns(current_timestamp, start) / 1.0e9;
    freq = (double)beats / (delta_s * 1.0e3);

    printf("Time elapsed: %.3f s\nEstimated frequency: %.3f kHz\n", delta_s, freq);
}

#ifdef __cplusplus
}
#endif
