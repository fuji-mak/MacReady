#include "SMCBridge.h"
#include <stddef.h>
#include <string.h>

// AppleSMC's private user-client ABI. Use C layout on both arm64 and x86_64.
// Protocol reference: https://github.com/vladkens/macmon/blob/main/src/sources.rs
typedef struct {
    uint8_t major, minor, build, reserved;
    uint16_t release;
} SMCVersion;

typedef struct {
    uint16_t version, length;
    uint32_t cpu, gpu, memory;
} SMCPowerLimit;

typedef struct {
    uint32_t size, type;
    uint8_t attributes;
} SMCKeyInfo;

typedef struct {
    uint32_t key;
    SMCVersion version;
    SMCPowerLimit powerLimit;
    SMCKeyInfo info;
    uint8_t result, status, command;
    uint32_t index;
    uint8_t bytes[32];
} SMCRequest;

_Static_assert(sizeof(SMCRequest) == 80, "Invalid SMC request size");
_Static_assert(offsetof(SMCRequest, info) == 28, "Invalid SMC key info offset");
_Static_assert(offsetof(SMCRequest, command) == 42, "Invalid SMC command offset");
_Static_assert(offsetof(SMCRequest, bytes) == 48, "Invalid SMC bytes offset");

static kern_return_t call(io_connect_t connection, const SMCRequest *input, SMCRequest *output) {
    size_t size = sizeof(*output);
    memset(output, 0, size);
    kern_return_t result = IOConnectCallStructMethod(connection, 2, input, sizeof(*input), output, &size);
    if (result != KERN_SUCCESS) return result;
    if (size != sizeof(*output)) return kIOReturnBadArgument;
    if (output->result == 132) return kIOReturnNotFound;
    return output->result == 0 ? KERN_SUCCESS : kIOReturnError;
}

kern_return_t mr_smc_open(io_connect_t *connection) {
    *connection = IO_OBJECT_NULL;
    io_iterator_t iterator = IO_OBJECT_NULL;
    kern_return_t result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSMC"), &iterator);
    if (result != KERN_SUCCESS) return result;
    result = kIOReturnNotFound;
    io_service_t service;
    while ((service = IOIteratorNext(iterator)) != IO_OBJECT_NULL) {
        result = IOServiceOpen(service, mach_task_self(), 0, connection);
        IOObjectRelease(service);
        if (result == KERN_SUCCESS) break;
    }
    IOObjectRelease(iterator);
    return result;
}

kern_return_t mr_smc_read(io_connect_t connection, uint32_t key, MRSMCValue *value) {
    memset(value, 0, sizeof(*value));
    SMCRequest input = {0}, output;
    input.key = key;
    input.command = 9; // Read key metadata.
    kern_return_t result = call(connection, &input, &output);
    if (result != KERN_SUCCESS) return result;
    if (output.info.size == 0 || output.info.size > sizeof(value->bytes)) return kIOReturnBadArgument;
    input.info = output.info;
    input.command = 5; // Read bytes.
    result = call(connection, &input, &output);
    if (result != KERN_SUCCESS) return result;
    value->type = input.info.type;
    value->size = input.info.size;
    memcpy(value->bytes, output.bytes, value->size);
    return KERN_SUCCESS;
}
