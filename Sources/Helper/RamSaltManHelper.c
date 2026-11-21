#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <mach/mach.h>
#include <IOKit/IOKitLib.h>

#define KERNEL_INDEX_SMC 2
#define SMC_CMD_READ_KEYINFO 9
#define SMC_CMD_READ_BYTES 5
#define SMC_CMD_WRITE_BYTES 8

typedef struct {
    uint8_t major, minor, build, reserved;
    uint16_t release;
} SMCKeyData_vers_t;

typedef struct {
    uint16_t version, length;
    uint32_t cpuPLimit, gpuPLimit, memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
    uint32_t dataSize, dataType;
    uint8_t dataAttributes;
} SMCKeyData_keyInfo_t;

typedef struct {
    uint32_t key;
    SMCKeyData_vers_t vers;
    SMCKeyData_pLimitData_t pLimitData;
    SMCKeyData_keyInfo_t keyInfo;
    uint8_t result, status, data8;
    uint32_t data32;
    uint8_t bytes[32];
} SMCKeyData_t;

static uint32_t fourCC(const char *str) {
    uint32_t res = 0;
    for (int i = 0; i < 4 && str[i]; i++) res = (res << 8) | (uint8_t)str[i];
    return res;
}

static kern_return_t smc_write(io_connect_t conn, const char *keyStr, const void *bytes, int size) {
    SMCKeyData_t inData, outData;
    memset(&inData, 0, sizeof(inData));
    inData.key = fourCC(keyStr);
    inData.data8 = SMC_CMD_READ_KEYINFO;
    size_t s = sizeof(SMCKeyData_t);
    IOConnectCallStructMethod(conn, KERNEL_INDEX_SMC, &inData, s, &outData, &s);
    inData.keyInfo = outData.keyInfo;
    if (inData.keyInfo.dataSize == 0 && size > 0) inData.keyInfo.dataSize = size;
    inData.data8 = SMC_CMD_WRITE_BYTES;
    memcpy(inData.bytes, bytes, size);
    return IOConnectCallStructMethod(conn, KERNEL_INDEX_SMC, &inData, s, &outData, &s);
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: RamSaltManHelper <--set fanIndex rpm | --auto fanIndex | --reset>\n");
        return 1;
    }

    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return 1;
    io_connect_t conn = 0;
    if (IOServiceOpen(service, mach_task_self(), 0, &conn) != KERN_SUCCESS) return 1;

    if (strcmp(argv[1], "--set") == 0 && argc >= 4) {
        int fan = atoi(argv[2]);
        float rpm = atof(argv[3]);
        if (rpm < 1000.0f) rpm = 1000.0f;
        if (rpm > 6500.0f) rpm = 6500.0f;

        // 1. Force Test unlock
        uint8_t one = 1;
        smc_write(conn, "Ftst", &one, 1);
        usleep(50000); // 50ms

        // 2. Set mode to 1 (Manual)
        char modeKey[5];
        snprintf(modeKey, sizeof(modeKey), "F%dMd", fan);
        smc_write(conn, modeKey, &one, 1);
        snprintf(modeKey, sizeof(modeKey), "F%dmd", fan);
        smc_write(conn, modeKey, &one, 1);

        // 3. Write target RPM
        char targetKey[5];
        snprintf(targetKey, sizeof(targetKey), "F%dTg", fan);
        smc_write(conn, targetKey, &rpm, sizeof(float));

        // Also update FS! bitmask if Intel Mac
        // ...
    } else if (strcmp(argv[1], "--auto") == 0 && argc >= 3) {
        int fan = atoi(argv[2]);
        uint8_t zero = 0;
        char modeKey[5];
        snprintf(modeKey, sizeof(modeKey), "F%dMd", fan);
        smc_write(conn, modeKey, &zero, 1);
        snprintf(modeKey, sizeof(modeKey), "F%dmd", fan);
        smc_write(conn, modeKey, &zero, 1);
        smc_write(conn, "Ftst", &zero, 1);
    } else if (strcmp(argv[1], "--reset") == 0) {
        uint8_t zero = 0;
        for (int i = 0; i < 4; i++) {
            char modeKey[5];
            snprintf(modeKey, sizeof(modeKey), "F%dMd", i);
            smc_write(conn, modeKey, &zero, 1);
            snprintf(modeKey, sizeof(modeKey), "F%dmd", i);
            smc_write(conn, modeKey, &zero, 1);
        }
        smc_write(conn, "Ftst", &zero, 1);
    }

    IOServiceClose(conn);
    return 0;
}
