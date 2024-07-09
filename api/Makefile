.PHONY: all clean

ifeq ($(RTE_SDK),)
$(error "Please define RTE_SDK environment variable")
endif

ifneq ($(shell pkg-config --exists libdpdk && echo 0),0)
$(error "no installation of DPDK found")
endif

PKGCONF ?= pkg-config
PC_FILE := $(shell $(PKGCONF) --path libdpdk 2>/dev/null)

BUILD_DIR = build

CC = g++
CFLAGS = -c -fPIC -Wall -O3 $(shell $(PKGCONF) --cflags libdpdk) -I$(RTE_SDK)/drivers/net/qdma
LDFLAGS = -shared $(shell $(PKGCONF) --libs libdpdk) -lrte_net_qdma

LIB_SRCS = va_lib.c perf.c dpi.c
LIBS_OBJS = $(patsubst %.c, $(BUILD_DIR)/%.o, $(LIB_SRCS))
LIBRARY = libfpga_va.so

# $(info $(shell $(CC) -v))

all: directories $(SOURCES) $(LIBRARY)

directories:
	@mkdir -p $(BUILD_DIR)

$(LIBRARY): $(LIBS_OBJS)
	$(CC) $(LIBS_OBJS) $(LDFLAGS) -o $@

$(BUILD_DIR)/%.o: %.c* $(PC_FILE)
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f $(LIBS_OBJS) $(LIBRARY)
