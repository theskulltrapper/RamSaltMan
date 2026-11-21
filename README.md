# RamSaltMan

An ultra-lightweight, zero-telemetry macOS system monitor and fan controller built by Shauryaveer Singh Sapra ([@theskulltrapper](https://github.com/theskulltrapper)).

## Features

- **Customizable Menu Bar**: Display RAM, CPU, Fan speed, and temperatures in any combination.
- **Resource Efficient**: Native Swift and C implementation with minimal CPU and memory usage.
- **Manual Fan Controls**: Preset modes (Auto, Quiet, Balanced, Max) and custom target RPM sliders with automatic thermal safeguards.
- **Hardware Telemetry**: Live or on-demand readings for CPU, GPU, SoC, and battery sensors.
- **Privacy & Security**: Zero network connections, no telemetry, and sandboxed storage access.

## Building from Source

```bash
make app    # Compiles RamSaltMan.app
make dmg    # Builds release disk image
make run    # Launches the application
```

## Developer

- Author: Shauryaveer Singh Sapra
- Profile: https://github.com/theskulltrapper
