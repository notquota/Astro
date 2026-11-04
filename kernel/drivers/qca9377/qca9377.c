#include "qca9377.h"

static void qca9377_clear(qca9377_device *device) {
    device->config_address = 0;
    device->subsystem_id = 0;
    device->bar0_raw = 0;
    device->bar1_raw = 0;
    device->mmio_physical_address = 0;
    device->revision = 0;
    device->bar_is_64bit = 0;
    device->present = 0;
    device->board_matches = 0;
}

int qca9377_probe_pci(
    qca9377_pci_read32_fn read_config,
    qca9377_device *device
) {
    if (!read_config || !device) {
        return QCA9377_PROBE_INVALID_ARGUMENT;
    }

    qca9377_clear(device);

    for (uint32_t bus = 0; bus < 256; ++bus) {
        for (uint32_t slot = 0; slot < 32; ++slot) {
            for (uint32_t function = 0; function < 8; ++function) {
                uint32_t address = 0x80000000u
                    | (bus << 16)
                    | (slot << 11)
                    | (function << 8);

                uint32_t id = read_config(address);

                if ((id & 0xFFFFu) == 0xFFFFu) {
                    if (function == 0) {
                        break;
                    }
                    continue;
                }

                if (id != (
                    (QCA9377_DEVICE_ID << 16)
                    | QCA9377_VENDOR_ID
                )) {
                    continue;
                }

                uint32_t class_revision = read_config(address | 0x08u);
                uint32_t bar0 = read_config(address | 0x10u);
                uint32_t bar1 = 0;

                device->config_address = address;
                device->subsystem_id = read_config(address | 0x2Cu);
                device->revision = (uint8_t)class_revision;
                device->bar0_raw = bar0;
                device->present = 1;

                device->board_matches = (
                    device->subsystem_id == QCA9377_EXPECTED_SUBSYSTEM
                );

                if (
                    bar0 == 0 ||
                    bar0 == 0xFFFFFFFFu ||
                    (bar0 & 1u)
                ) {
                    return QCA9377_PROBE_INVALID_BAR;
                }

                uint32_t bar_type = (bar0 >> 1) & 3u;

                if (bar_type == 0u) {
                    device->mmio_physical_address =
                        (uint64_t)(bar0 & ~0xFu);
                } else if (bar_type == 2u) {
                    bar1 = read_config(address | 0x14u);

                    device->bar1_raw = bar1;
                    device->bar_is_64bit = 1;

                    device->mmio_physical_address =
                        ((uint64_t)bar1 << 32)
                        | (uint64_t)(bar0 & ~0xFu);
                } else {
                    return QCA9377_PROBE_INVALID_BAR;
                }

                if (device->mmio_physical_address == 0) {
                    return QCA9377_PROBE_INVALID_BAR;
                }

                return QCA9377_PROBE_FOUND;
            }
        }
    }

    return QCA9377_PROBE_NOT_FOUND;
}