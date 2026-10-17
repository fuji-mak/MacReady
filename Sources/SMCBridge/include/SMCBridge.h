#ifndef MACREADY_SMC_BRIDGE_H
#define MACREADY_SMC_BRIDGE_H

#include <IOKit/IOKitLib.h>
#include <stdint.h>

typedef struct {
    uint32_t type;
    uint32_t size;
    uint8_t bytes[32];
} MRSMCValue;

// Read-only AppleSMC transport. No write command is exposed.
kern_return_t mr_smc_open(io_connect_t *connection);
kern_return_t mr_smc_read(io_connect_t connection, uint32_t key, MRSMCValue *value);

#endif
