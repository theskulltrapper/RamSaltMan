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

bool smc_bridge_init(void);
void smc_bridge_close(void);
int smc_bridge_get_fan_count(void);
bool smc_bridge_get_fan_info(int fanIndex, FanData *outData);
bool smc_bridge_set_fan_speed(int fanIndex, float targetRPM);
bool smc_bridge_set_fan_auto(int fanIndex);
bool smc_bridge_reset_all_fans(void);
bool smc_bridge_get_thermals(ThermalData *outData);

// Privileged Helper Management for Apple Silicon
bool smc_bridge_is_helper_installed(void);
bool smc_bridge_install_helper(const char *bundledHelperPath);

#ifdef __cplusplus
}
#endif

#endif /* RAMSALTMAN_SMC_BRIDGE_H */
