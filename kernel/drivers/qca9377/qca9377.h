#ifndef A5TR0_QCA9377_H
#define A5TR0_QCA9377_H

#include <stdint.h>

#define QCA9377_VENDOR_ID 0x168Cu
#define QCA9377_DEVICE_ID 0x0042u
#define QCA9377_EXPECTED_SUBSYSTEM 0x08A611ADu
#define QCA9377_EXPECTED_REVISION 0x31u

#define QCA9377_PROBE_NOT_FOUND 0
#define QCA9377_PROBE_FOUND 1
#define QCA9377_PROBE_INVALID_ARGUMENT -1
#define QCA9377_PROBE_INVALID_BAR -2

typedef uint32_t (*qca9377_pci_read32_fn)(uint32_t config_address);

typedef struct {
    uint32_t config_address;
    uint32_t subsystem_id;
    uint32_t bar0_raw;
    uint32_t bar1_raw;
    uint64_t mmio_physical_address;
    uint8_t revision;
    uint8_t bar_is_64bit;
    uint8_t present;
    uint8_t board_matches;
} qca9377_device;

int qca9377_probe_pci(
    qca9377_pci_read32_fn read_config,
    qca9377_device *device
);

#endif