#include "SMCBridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>

#define KERNEL_INDEX_SMC 2
#define SMC_CMD_READ_KEYINFO 9
#define SMC_CMD_READ_BYTES 5
#define SMC_CMD_WRITE_BYTES 8

#define SMC_KEY_FNUM "FNum"
#define SMC_KEY_FS "FS! "

#define MAX_FANS 8

typedef struct {
    uint8_t major;
    uint8_t minor;
    uint8_t build;
    uint8_t reserved;
    uint16_t release;
} SMCKeyData_vers_t;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
    uint32_t dataSize;
    uint32_t dataType;
    uint8_t dataAttributes;
} SMCKeyData_keyInfo_t;

typedef struct {
    uint32_t key;
    SMCKeyData_vers_t vers;
    SMCKeyData_pLimitData_t pLimitData;
    SMCKeyData_keyInfo_t keyInfo;
    uint8_t result;
    uint8_t status;
    uint8_t data8;
    uint32_t data32;
    uint8_t bytes[32];
} SMCKeyData_t;

static io_connect_t g_smc_conn = 0;
static pthread_mutex_t g_smc_mutex = PTHREAD_MUTEX_INITIALIZER;
static bool g_initialized = false;
static int g_fan_count = 0;

// Dynamic IOHIDEventSystemClient bindings for Apple Silicon Thermal telemetry
typedef void *IOHIDEventSystemClientRef;
typedef void *IOHIDServiceClientRef;
typedef void *IOHIDEventRef;

static IOHIDEventSystemClientRef (*pIOHIDEventSystemClientCreate)(CFAllocatorRef) = NULL;
static void (*pIOHIDEventSystemClientSetMatching)(IOHIDEventSystemClientRef, CFDictionaryRef) = NULL;
static CFArrayRef (*pIOHIDEventSystemClientCopyServices)(IOHIDEventSystemClientRef) = NULL;
static CFTypeRef (*pIOHIDServiceClientCopyProperty)(IOHIDServiceClientRef, CFStringRef) = NULL;
static IOHIDEventRef (*pIOHIDServiceClientCopyEvent)(IOHIDServiceClientRef, int64_t, int32_t, int64_t) = NULL;
static double (*pIOHIDEventGetFloatValue)(IOHIDEventRef, uint32_t) = NULL;

static IOHIDEventSystemClientRef g_hid_client = NULL;
static bool g_hid_initialized = false;

static uint32_t fourCC(const char *str) {
    uint32_t res = 0;
    for (int i = 0; i < 4 && str[i]; i++) {
        res = (res << 8) | (uint8_t)str[i];
    }
    return res;
}

static kern_return_t smc_call(int cmd, const char *keyStr, SMCKeyData_t *valInOut) {
    SMCKeyData_t inData;
    memset(&inData, 0, sizeof(inData));
    inData.key = fourCC(keyStr);
    inData.data8 = cmd;

    if (cmd == SMC_CMD_READ_BYTES || cmd == SMC_CMD_WRITE_BYTES) {
        inData.keyInfo = valInOut->keyInfo;
        if (cmd == SMC_CMD_WRITE_BYTES) {
            memcpy(inData.bytes, valInOut->bytes, sizeof(inData.bytes));
        }
    }

    SMCKeyData_t outData;
    memset(&outData, 0, sizeof(outData));
    size_t inSize = sizeof(SMCKeyData_t);
    size_t outSize = sizeof(SMCKeyData_t);

    kern_return_t kr = IOConnectCallStructMethod(g_smc_conn, KERNEL_INDEX_SMC, &inData, inSize, &outData, &outSize);
    if (kr == KERN_SUCCESS && outData.result == 0) {
        *valInOut = outData;
        return KERN_SUCCESS;
    }
    return kr != KERN_SUCCESS ? kr : -1;
}

static kern_return_t smc_read(const char *keyStr, SMCKeyData_t *valOut) {
    SMCKeyData_t info;
    memset(&info, 0, sizeof(info));
    kern_return_t kr = smc_call(SMC_CMD_READ_KEYINFO, keyStr, &info);
    if (kr != KERN_SUCCESS) return kr;

    valOut->keyInfo = info.keyInfo;
    return smc_call(SMC_CMD_READ_BYTES, keyStr, valOut);
}

static kern_return_t smc_write(const char *keyStr, const SMCKeyData_t *valIn) {
    SMCKeyData_t info;
    memset(&info, 0, sizeof(info));
    kern_return_t kr = smc_call(SMC_CMD_READ_KEYINFO, keyStr, &info);
    if (kr != KERN_SUCCESS) return kr;

    SMCKeyData_t target = *valIn;
    target.keyInfo = info.keyInfo;
    return smc_call(SMC_CMD_WRITE_BYTES, keyStr, &target);
}

static float parse_speed(const SMCKeyData_t *data) {
    uint32_t dt = data->keyInfo.dataType;
    // 'flt ' = 0x666C7420
    if (dt == 0x666C7420) {
        float f = 0.0f;
        memcpy(&f, data->bytes, sizeof(float));
        return f;
    }
    // 'fpe2' = 0x66706532 (Fixed point 14.2)
    if (dt == 0x66706532) {
        return (float)((data->bytes[0] << 6) | (data->bytes[1] >> 2));
    }
    return 0.0f;
}

static void encode_speed(float speed, uint32_t dt, uint8_t *outBytes) {
    if (dt == 0x666C7420) { // flt
        memcpy(outBytes, &speed, sizeof(float));
    } else { // fpe2
        uint16_t fixed = (uint16_t)(speed * 4.0f);
        outBytes[0] = (uint8_t)(fixed >> 8);
        outBytes[1] = (uint8_t)(fixed & 0xFF);
    }
}

static void init_hid_client(void) {
    if (g_hid_initialized) return;

    void *handle = dlopen(NULL, RTLD_NOW);
    if (!handle) return;

    pIOHIDEventSystemClientCreate = (IOHIDEventSystemClientRef (*)(CFAllocatorRef))dlsym(handle, "IOHIDEventSystemClientCreate");
    pIOHIDEventSystemClientSetMatching = (void (*)(IOHIDEventSystemClientRef, CFDictionaryRef))dlsym(handle, "IOHIDEventSystemClientSetMatching");
    pIOHIDEventSystemClientCopyServices = (CFArrayRef (*)(IOHIDEventSystemClientRef))dlsym(handle, "IOHIDEventSystemClientCopyServices");
    pIOHIDServiceClientCopyProperty = (CFTypeRef (*)(IOHIDServiceClientRef, CFStringRef))dlsym(handle, "IOHIDServiceClientCopyProperty");
    pIOHIDServiceClientCopyEvent = (IOHIDEventRef (*)(IOHIDServiceClientRef, int64_t, int32_t, int64_t))dlsym(handle, "IOHIDServiceClientCopyEvent");
    pIOHIDEventGetFloatValue = (double (*)(IOHIDEventRef, uint32_t))dlsym(handle, "IOHIDEventGetFloatValue");

    if (pIOHIDEventSystemClientCreate && pIOHIDEventSystemClientSetMatching && pIOHIDEventSystemClientCopyServices) {
        g_hid_client = pIOHIDEventSystemClientCreate(kCFAllocatorDefault);
        if (g_hid_client) {
            int page = 0xff00; // AppleVendor
            int usage = 5;     // TemperatureSensor
            CFNumberRef pageNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &page);
            CFNumberRef usageNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &usage);

            const void *keys[] = { CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage") };
            const void *vals[] = { pageNum, usageNum };
            CFDictionaryRef matchDict = CFDictionaryCreate(kCFAllocatorDefault, keys, vals, 2,
                                                           &kCFTypeDictionaryKeyCallBacks,
                                                           &kCFTypeDictionaryValueCallBacks);
            pIOHIDEventSystemClientSetMatching(g_hid_client, matchDict);
            CFRelease(matchDict);
            CFRelease(pageNum);
            CFRelease(usageNum);
            g_hid_initialized = true;
        }
    }
}

bool smc_bridge_init(void) {
    pthread_mutex_lock(&g_smc_mutex);
    if (g_initialized && g_smc_conn != 0) {
        pthread_mutex_unlock(&g_smc_mutex);
        return true;
    }

    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) {
        pthread_mutex_unlock(&g_smc_mutex);
        return false;
    }

    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &g_smc_conn);
    IOObjectRelease(service);
    if (kr != KERN_SUCCESS || g_smc_conn == 0) {
        pthread_mutex_unlock(&g_smc_mutex);
        return false;
    }

    // Read fan count
    SMCKeyData_t val;
    memset(&val, 0, sizeof(val));
    if (smc_read(SMC_KEY_FNUM, &val) == KERN_SUCCESS) {
        g_fan_count = (int)val.bytes[0];
        if (g_fan_count > MAX_FANS) g_fan_count = MAX_FANS;
    } else {
        g_fan_count = 0;
    }

    init_hid_client();

    g_initialized = true;
    pthread_mutex_unlock(&g_smc_mutex);
    return true;
}

void smc_bridge_close(void) {
    pthread_mutex_lock(&g_smc_mutex);
    if (g_smc_conn != 0) {
        IOServiceClose(g_smc_conn);
        g_smc_conn = 0;
    }
    if (g_hid_client != NULL) {
        CFRelease((CFTypeRef)g_hid_client);
        g_hid_client = NULL;
        g_hid_initialized = false;
    }
    g_initialized = false;
    pthread_mutex_unlock(&g_smc_mutex);
}

int smc_bridge_get_fan_count(void) {
    if (!g_initialized) {
        if (!smc_bridge_init()) return 0;
    }
    return g_fan_count;
}

bool smc_bridge_get_fan_info(int fanIndex, FanData *outData) {
    if (!outData || fanIndex < 0 || fanIndex >= g_fan_count) return false;
    if (!g_initialized) {
        if (!smc_bridge_init()) return false;
    }

    pthread_mutex_lock(&g_smc_mutex);

    memset(outData, 0, sizeof(FanData));
    outData->fanIndex = fanIndex;
    if (fanIndex == 0) {
        snprintf(outData->name, sizeof(outData->name), "Left Fan");
    } else if (fanIndex == 1) {
        snprintf(outData->name, sizeof(outData->name), "Right Fan");
    } else {
        snprintf(outData->name, sizeof(outData->name), "Fan %d", fanIndex + 1);
    }

    char key[5];
    SMCKeyData_t val;

    // Actual RPM
    snprintf(key, sizeof(key), "F%dAc", fanIndex);
    if (smc_read(key, &val) == KERN_SUCCESS) {
        outData->currentRPM = parse_speed(&val);
    }

    // Min RPM
    snprintf(key, sizeof(key), "F%dMn", fanIndex);
    if (smc_read(key, &val) == KERN_SUCCESS) {
        outData->minRPM = parse_speed(&val);
    }

    // Max RPM
    snprintf(key, sizeof(key), "F%dMx", fanIndex);
    if (smc_read(key, &val) == KERN_SUCCESS) {
        outData->maxRPM = parse_speed(&val);
    }

    // Target RPM
    snprintf(key, sizeof(key), "F%dTg", fanIndex);
    if (smc_read(key, &val) == KERN_SUCCESS) {
        outData->targetRPM = parse_speed(&val);
    }

    // Mode: FS! or F%dMd
    bool manual = false;
    if (smc_read(SMC_KEY_FS, &val) == KERN_SUCCESS) {
        uint16_t modeMask = (val.bytes[0] << 8) | val.bytes[1];
        if (modeMask & (1 << fanIndex)) {
            manual = true;
        }
    }
    snprintf(key, sizeof(key), "F%dMd", fanIndex);
    if (smc_read(key, &val) == KERN_SUCCESS) {
        if (val.bytes[0] == 1) manual = true;
    }
    outData->isManual = manual;

    pthread_mutex_unlock(&g_smc_mutex);
    return true;
}

bool smc_bridge_set_fan_speed(int fanIndex, float targetRPM) {
    if (fanIndex < 0 || fanIndex >= g_fan_count) return false;
    if (!g_initialized) {
        if (!smc_bridge_init()) return false;
    }

    pthread_mutex_lock(&g_smc_mutex);

    // Fetch bounds
    char key[5];
    SMCKeyData_t val;
    float minR = 1200.0f, maxR = 6000.0f;

    snprintf(key, sizeof(key), "F%dMn", fanIndex);
    if (smc_read(key, &val) == KERN_SUCCESS) minR = parse_speed(&val);

    snprintf(key, sizeof(key), "F%dMx", fanIndex);
    if (smc_read(key, &val) == KERN_SUCCESS) maxR = parse_speed(&val);

    if (targetRPM < minR) targetRPM = minR;
    if (targetRPM > maxR) targetRPM = maxR;

    // 1. Enable manual mode via FS!
    memset(&val, 0, sizeof(val));
    if (smc_read(SMC_KEY_FS, &val) == KERN_SUCCESS) {
        uint16_t mask = (val.bytes[0] << 8) | val.bytes[1];
        mask |= (1 << fanIndex);
        val.bytes[0] = (uint8_t)(mask >> 8);
        val.bytes[1] = (uint8_t)(mask & 0xFF);
        smc_write(SMC_KEY_FS, &val);
    }

    // 2. Also write F%dMd = 1 if present
    snprintf(key, sizeof(key), "F%dMd", fanIndex);
    memset(&val, 0, sizeof(val));
    val.bytes[0] = 1;
    smc_write(key, &val);

    // 3. Write target RPM
    snprintf(key, sizeof(key), "F%dTg", fanIndex);
    memset(&val, 0, sizeof(val));
    if (smc_call(SMC_CMD_READ_KEYINFO, key, &val) == KERN_SUCCESS) {
        encode_speed(targetRPM, val.keyInfo.dataType, val.bytes);
        smc_call(SMC_CMD_WRITE_BYTES, key, &val);
    }

    pthread_mutex_unlock(&g_smc_mutex);
    return true;
}

bool smc_bridge_set_fan_auto(int fanIndex) {
    if (fanIndex < 0 || fanIndex >= g_fan_count) return false;
    if (!g_initialized) {
        if (!smc_bridge_init()) return false;
    }

    pthread_mutex_lock(&g_smc_mutex);

    // Clear bit in FS!
    SMCKeyData_t val;
    memset(&val, 0, sizeof(val));
    if (smc_read(SMC_KEY_FS, &val) == KERN_SUCCESS) {
        uint16_t mask = (val.bytes[0] << 8) | val.bytes[1];
        mask &= ~(1 << fanIndex);
        val.bytes[0] = (uint8_t)(mask >> 8);
        val.bytes[1] = (uint8_t)(mask & 0xFF);
        smc_write(SMC_KEY_FS, &val);
    }

    // Set F%dMd = 0
    char key[5];
    snprintf(key, sizeof(key), "F%dMd", fanIndex);
    memset(&val, 0, sizeof(val));
    val.bytes[0] = 0;
    smc_write(key, &val);

    pthread_mutex_unlock(&g_smc_mutex);
    return true;
}

bool smc_bridge_reset_all_fans(void) {
    if (!g_initialized) {
        if (!smc_bridge_init()) return false;
    }

    pthread_mutex_lock(&g_smc_mutex);

    SMCKeyData_t val;
    memset(&val, 0, sizeof(val));
    val.bytes[0] = 0;
    val.bytes[1] = 0;
    smc_write(SMC_KEY_FS, &val);

    for (int i = 0; i < g_fan_count; i++) {
        char key[5];
        snprintf(key, sizeof(key), "F%dMd", i);
        memset(&val, 0, sizeof(val));
        val.bytes[0] = 0;
        smc_write(key, &val);
    }

    pthread_mutex_unlock(&g_smc_mutex);
    return true;
}

bool smc_bridge_get_thermals(ThermalData *outData) {
    if (!outData) return false;
    memset(outData, 0, sizeof(ThermalData));

    // Try IOHIDEventSystemClient first (Apple Silicon & modern macOS)
    if (g_hid_initialized && g_hid_client && pIOHIDEventSystemClientCopyServices &&
        pIOHIDServiceClientCopyProperty && pIOHIDServiceClientCopyEvent && pIOHIDEventGetFloatValue) {
        CFArrayRef services = pIOHIDEventSystemClientCopyServices(g_hid_client);
        if (services) {
            CFIndex count = CFArrayGetCount(services);
            double cpuSum = 0; int cpuCount = 0;
            double gpuSum = 0; int gpuCount = 0;
            double socSum = 0; int socCount = 0;
            double batSum = 0; int batCount = 0;
            double maxT = 0;

            for (CFIndex i = 0; i < count; i++) {
                IOHIDServiceClientRef s = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
                CFTypeRef prop = pIOHIDServiceClientCopyProperty(s, CFSTR("Product"));
                char nameBuf[128] = {0};
                if (prop && CFGetTypeID(prop) == CFStringGetTypeID()) {
                    CFStringGetCString((CFStringRef)prop, nameBuf, sizeof(nameBuf), kCFStringEncodingUTF8);
                }
                if (prop) CFRelease(prop);

                IOHIDEventRef event = pIOHIDServiceClientCopyEvent(s, 15, 0, 0); // 15 = IOHIDEventTypeTemperature
                if (event) {
                    double t = pIOHIDEventGetFloatValue(event, (15 << 16));
                    CFRelease((CFTypeRef)event);

                    if (t > 0 && t < 125.0) {
                        if (t > maxT) maxT = t;

                        // Check sensor name
                        char lowerName[128];
                        for (int j = 0; nameBuf[j] && j < 127; j++) lowerName[j] = (char)tolower(nameBuf[j]);
                        lowerName[strlen(nameBuf)] = '\0';

                        if (strstr(lowerName, "cpu") || strstr(lowerName, "tdie") || strstr(lowerName, "core") || strstr(lowerName, "tp")) {
                            cpuSum += t;
                            cpuCount++;
                        } else if (strstr(lowerName, "gpu") || strstr(lowerName, "tg")) {
                            gpuSum += t;
                            gpuCount++;
                        } else if (strstr(lowerName, "soc") || strstr(lowerName, "pmu") || strstr(lowerName, "tdev")) {
                            socSum += t;
                            socCount++;
                        } else if (strstr(lowerName, "bat") || strstr(lowerName, "bms") || strstr(lowerName, "gas")) {
                            batSum += t;
                            batCount++;
                        }
                    }
                }
            }
            CFRelease(services);

            if (cpuCount > 0 || maxT > 0) {
                outData->cpuTemp = (float)(cpuCount > 0 ? (cpuSum / cpuCount) : maxT);
                outData->gpuTemp = (float)(gpuCount > 0 ? (gpuSum / gpuCount) : outData->cpuTemp);
                outData->socTemp = (float)(socCount > 0 ? (socSum / socCount) : outData->cpuTemp);
                outData->batteryTemp = (float)(batCount > 0 ? (batSum / batCount) : 32.0f);
                outData->maxTemp = (float)maxT;
                outData->hasSensors = true;
                return true;
            }
        }
    }

    // Fallback: Intel SMC thermal keys
    if (!g_initialized) {
        if (!smc_bridge_init()) return false;
    }

    pthread_mutex_lock(&g_smc_mutex);
    const char *cpuKeys[] = { "TC0P", "TC0D", "TC0E", "TC0F" };
    float cSum = 0; int cCnt = 0;
    for (int i = 0; i < 4; i++) {
        SMCKeyData_t v;
        if (smc_read(cpuKeys[i], &v) == KERN_SUCCESS) {
            float t = (float)((v.bytes[0] << 6) | (v.bytes[1] >> 2));
            if (t > 15.0f && t < 115.0f) { cSum += t; cCnt++; }
        }
    }

    SMCKeyData_t gVal;
    float gpuT = 0;
    if (smc_read("TG0P", &gVal) == KERN_SUCCESS) {
        gpuT = (float)((gVal.bytes[0] << 6) | (gVal.bytes[1] >> 2));
    }

    pthread_mutex_unlock(&g_smc_mutex);

    if (cCnt > 0) {
        outData->cpuTemp = cSum / cCnt;
        outData->gpuTemp = gpuT > 0 ? gpuT : outData->cpuTemp;
        outData->socTemp = outData->cpuTemp;
        outData->batteryTemp = 30.0f;
        outData->maxTemp = outData->cpuTemp > outData->gpuTemp ? outData->cpuTemp : outData->gpuTemp;
        outData->hasSensors = true;
        return true;
    }

    return false;
}
