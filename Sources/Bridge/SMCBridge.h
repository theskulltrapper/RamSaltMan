#ifndef RAMSALTMAN_SMC_BRIDGE_H
#define RAMSALTMAN_SMC_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int fanIndex;
    char name[32];
    float currentRPM;
    float minRPM;
    float maxRPM;
    float targetRPM;
    bool isManual;
} FanData;

typedef struct {
    float cpuTemp;      // CPU Average / Die (°C)
    float gpuTemp;      // GPU Average (°C)
    float socTemp;      // System-on-Chip (°C)
    float batteryTemp;  // Battery (°C)
    float maxTemp;      // Maximum sensor reading (°C)
    bool hasSensors;    // Whether thermal sensors are active
} ThermalData;

/**
 * Initialize SMC connection and HID sensor client.
 * Returns true if SMC / sensors were initialized successfully.
 */
bool smc_bridge_init(void);

/**
 * Close SMC connection and clean up resources.
 */
void smc_bridge_close(void);

/**
 * Query the number of active cooling fans detected by the hardware.
 */
int smc_bridge_get_fan_count(void);

/**
 * Retrieve current fan telemetry (RPM, Min, Max, Target, Mode).
 */
bool smc_bridge_get_fan_info(int fanIndex, FanData *outData);

/**
 * Manually set fan speed for a specific fan index.
 * Target RPM is automatically clamped between minRPM and maxRPM.
 */
bool smc_bridge_set_fan_speed(int fanIndex, float targetRPM);

/**
 * Return specific fan to automatic system thermal management.
 */
bool smc_bridge_set_fan_auto(int fanIndex);

/**
 * Reset all fans to automatic system thermal management.
 */
bool smc_bridge_reset_all_fans(void);

/**
 * Query current live system temperatures.
 */
bool smc_bridge_get_thermals(ThermalData *outData);

#ifdef __cplusplus
}
#endif

#endif /* RAMSALTMAN_SMC_BRIDGE_H */
