#ifdef __cplusplus
extern "C" {
#endif

#include "va_lib.h"

uint16_t device_num;
device_info devices[DEVICES_MAX];

void va_init(int argc, char *argv[]) {
    int ret = 0;

    printf("VA init\n");

    printf("args[%d]:\n", argc);
    for(int i = 0; i < argc; i++) {
        printf("  args[%d] = %s\n", i, argv[i]);
    }

    // Init EAL
    ret = rte_eal_init(argc, argv);

    if(ret < 0)
        rte_exit(EXIT_FAILURE, "%s: failed to initialize EAL\n", __func__);
        
    // Get devices
    device_num = rte_eth_dev_count_avail();

    if(device_num < 0)
        rte_exit(EXIT_FAILURE, "%s: no available devices found\n", __func__);

    printf("Available devices: %d\n", device_num);

    rte_pmd_qdma_compat_memzone_reserve_aligned();
}

void va_deinit() {
    printf("VA deinit\n");
    rte_eal_cleanup();
}

int va_dev_open(uint16_t dev_id, uint32_t ring_depth, uint32_t buff_size) {
    int ret = 0;
    uint32_t mbuf_number;

    struct rte_mempool      *mbuf_pool;
	struct rte_eth_conf	    port_conf = {0};
	struct rte_eth_txconf   tx_conf = {0};
	struct rte_eth_rxconf   rx_conf = {0};

    const uint32_t queue_num = 1;
    const uint32_t queue_id = 0;

    printf("%s: id=%d ring_depth=%d buff_size=%d\n", __func__, dev_id, ring_depth, buff_size);

    if(rte_pmd_qdma_get_device(dev_id) == NULL) {
        printf("%s: device with port id=%d does not exist or is already removed\n", __func__, dev_id);
		return -1;
	}

    // Configure Ethernet device, default settings
    ret = rte_eth_dev_configure(dev_id, queue_num, queue_num, &port_conf);

	if(ret < 0)
		rte_exit(EXIT_FAILURE, "%s: cannot configure port %d (err=%d)\n", 
            __func__, dev_id, ret);

    // Configure mempool
    snprintf(devices[dev_id].mem_pool, RTE_MEMPOOL_NAMESIZE, MBUF_POOL_NAME_PORT, dev_id);

    mbuf_number = (ring_depth * queue_num * 2);

    mbuf_pool = rte_pktmbuf_pool_create(devices[dev_id].mem_pool, mbuf_number, 
                    0, 0, buff_size + RTE_PKTMBUF_HEADROOM, rte_socket_id());

    if(mbuf_pool == NULL)
        rte_exit(EXIT_FAILURE, "%s: failed to create mbuf pool: %s\n", __func__, rte_strerror(rte_errno));

    // Get BARs
    ret = rte_pmd_qdma_get_bar_details(
                dev_id, 
                &devices[dev_id].config_bar_idx,
                &devices[dev_id].user_bar_idx,
                &devices[dev_id].bypass_bar_idx
            );

    if(ret < 0)
        rte_exit(EXIT_FAILURE, "%s: rte_pmd_qdma_get_bar_details(): failed to get BARs\n", __func__);

    printf("QDMA Config bar idx: %d\n", devices[dev_id].config_bar_idx);
	printf("QDMA AXI Master Lite bar idx: %d\n", devices[dev_id].user_bar_idx);
	printf("QDMA AXI Bridge Master bar idx: %d\n", devices[dev_id].bypass_bar_idx);

    // Get queue base
    ret = rte_pmd_qdma_get_queue_base(dev_id, &devices[dev_id].queue_base);
	if(ret < 0)
		rte_exit(EXIT_FAILURE, "%s: rte_pmd_qdma_get_queue_base(): failed to query queue base\n", __func__);

    devices[dev_id].nb_descs = ring_depth;
    devices[dev_id].buff_size = buff_size;

    // Set queue to streaming mode
    ret = rte_pmd_qdma_set_queue_mode(dev_id, queue_id, RTE_PMD_QDMA_STREAMING_MODE);

    // Additional queue setup goes here
    // tx_conf.tx_thresh.hthresh = 1;
    // tx_conf.tx_thresh.pthresh = 1;
    // tx_conf.tx_thresh.wthresh = 1;

    // rx_conf.rx_thresh.hthresh = 1;
    // rx_conf.rx_thresh.pthresh = 1;
    // rx_conf.rx_thresh.wthresh = 1;

    if(ret < 0)
        rte_exit(EXIT_FAILURE, "%s: rte_pmd_qdma_set_queue_mode(): failed to set queue mode\n", __func__);

    ret = rte_eth_tx_queue_setup(dev_id, queue_id, ring_depth, 0, &tx_conf);

    if(ret < 0)
        rte_exit(EXIT_FAILURE, "%s: device id=%d setup TX queue id=%d failed (err=%d)\n", 
            __func__, dev_id, queue_id, ret);

    ret = rte_eth_rx_queue_setup(dev_id, queue_id, ring_depth, 0, &rx_conf, mbuf_pool);

    if(ret < 0)
        rte_exit(EXIT_FAILURE, "%s: device id=%d setup RX queue id=%d failed (err=%d)\n", 
            __func__, dev_id, queue_id, ret);

    // Start device
    ret = rte_eth_dev_start(dev_id);

	if(ret < 0)
		rte_exit(EXIT_FAILURE, "%s: cannot start device with id=%d (err=%d)\n", __func__, dev_id, ret);

    devices[dev_id].is_open = true;

    return 0;
}

int va_dev_close(uint16_t dev_id) {
    struct rte_mempool *mp;

    printf("%s: id=%d\n", __func__, dev_id);

    if(rte_pmd_qdma_get_device(dev_id) == NULL) {
		printf("%s: device with port id=%d does not exist or is already removed\n", __func__, dev_id);
		return -1;
	}

    rte_eth_dev_stop(dev_id);
    rte_pmd_qdma_dev_close(dev_id);

    devices[dev_id].is_open = false;

    // Free memory pool
    mp = rte_mempool_lookup(devices[dev_id].mem_pool);
	if(mp != NULL)
		rte_mempool_free(mp);

    return 0;
}

int va_dev_remove(uint16_t dev_id) {
    int ret = 0;

    printf("%s: id=%d\n", __func__, dev_id);

    ret = va_dev_close(dev_id);
    if(ret < 0) {
        return -1;
    }

	ret = rte_pmd_qdma_dev_remove(dev_id);
	if(ret < 0) {
		rte_exit(EXIT_FAILURE, "%s: failed to remove device with port id=%d\n", __func__, dev_id);
    }
    
	return 0;
}

int va_xmit(uint16_t dev_id, uint8_t *data, uint32_t len) {
    struct rte_mempool *mpool;
    struct rte_mbuf *mbuf;
    struct rte_mbuf *mbufs[1];
    uint8_t *payload_ptr;
    uint16_t tx_pkts_num;

    if(rte_pmd_qdma_get_device(dev_id) == NULL) {
		printf("%s: device with port id=%d does not exist or is already removed\n", __func__, dev_id);
		return -1;
	}

    if(len > devices[dev_id].buff_size) {
        printf(
            "%s: data length (%d) should be less or equal to device (id=%d) buffer size (%d)",
            __func__,
            len,
            dev_id,
            devices[dev_id].buff_size 
        );
    }

    mpool = rte_mempool_lookup(devices[dev_id].mem_pool);
	if(mpool == NULL) {
		printf("%s: could not find mempool with name %s\n", __func__, devices[dev_id].mem_pool);
		return -1;
	}

    mbuf = rte_pktmbuf_alloc(mpool);

    if(mbuf == NULL) {
        printf("%s: cannot allocate mbuf packet\n", __func__);
        return -1;
    }

    mbuf->nb_segs = 1;
    mbuf->next = NULL;
    mbuf->data_len = len;
    mbuf->pkt_len = len;

    payload_ptr = (uint8_t*)rte_pktmbuf_mtod(mbuf, uint8_t*);
    rte_memcpy(payload_ptr, data, len);

    mbufs[0] = mbuf;
    tx_pkts_num = rte_eth_tx_burst(dev_id, 0, mbufs, 1);
 
    if(!tx_pkts_num) {
        printf("%s: failed to send data\n", __func__);
        rte_pktmbuf_free(mbuf);
        return -1;
    }

    // printf("%s: sent %d packet(s)\n", __func__, tx_pkts_num);

    rte_pktmbuf_free(mbuf);

    return 0;
}

int va_recv(uint16_t dev_id, uint8_t *data, uint32_t len) {
    int rx_pkts_num;
    uint32_t retries;

    struct rte_mbuf *pkts[RX_BURST_SIZE] = {0};

    if(rte_pmd_qdma_get_device(dev_id) == NULL) {
		printf("%s: device with port id=%d does not exist or is already removed\n", __func__, dev_id);
		return -1;
	}

    if(len > devices[dev_id].buff_size) {
        printf(
            "%s: data length (%d) should be less or equal to device (id=%d) buffer size (%d)",
            __func__,
            len,
            dev_id,
            devices[dev_id].buff_size 
        );
    }

    retries = RX_MAX_RETRY;

    while(1) {
        retries -= 1;
        rx_pkts_num = rte_eth_rx_burst(0, 0, pkts, 8);

        if(rx_pkts_num) {
            break;
        }

        if(!retries) {
            printf("%s: failed to receive packets, timeout reached\n", __func__);
            return -1;
        }
    }

    // printf("%s: received %d packets, retries=%d\n", __func__, rx_pkts_num, RX_MAX_RETRY - retries);

    rte_memcpy(data, rte_pktmbuf_mtod(pkts[0], uint8_t*), MAX(rte_pktmbuf_pkt_len(pkts[0]), len));

    return 0;
}



#ifdef __cplusplus
}
#endif