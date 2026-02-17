# Codebase Structure

**Analysis Date:** 2026-02-17

## Directory Layout

```
[project-root]/
├── firmware/         # MicroPython firmware binaries (.uf2)
├── zour-dough-*.py   # Main application scripts
├── README.md         # Documentation
└── .planning/        # GSD/Agent planning documents
```

## Directory Purposes

**[Root]:**
- Purpose: Main application logic and entry points.
- Contains: Python scripts for sensor control.
- Key files: `zour-dough-ds18b20.py`, `zour-dough-dht22.py`.

**firmware/:**
- Purpose: Stores firmware binaries for target hardware.
- Contains: `.uf2` files for Raspberry Pi Pico / Pico W.
- Key files: `RPI_PICO-20251209-v1.27.0.uf2`, `RPI_PICO2_W-20251209-v1.27.0.uf2`.

## Key File Locations

**Entry Points:**
- `zour-dough-ds18b20.py`: Script for DS18B20 sensor integration.
- `zour-dough-dht22.py`: Script for DHT22 sensor integration.

**Configuration:**
- Constants defined at the top of each script (e.g., `MAX_TEMP`, `PIN` assignments).
- No separate configuration file detected.

**Core Logic:**
- `while True` loops inside each script handle sensor reading and heater control.

**Testing:**
- No formal testing framework or directory detected.
- Validation is likely done via manual hardware testing.

## Naming Conventions

**Files:**
- Kebab-case with descriptive names: `zour-dough-[sensor-type].py`
- Example: `zour-dough-ds18b20.py`

**Directories:**
- Lowercase standard: `firmware`

## Where to Add New Code

**New Sensor Integration:**
- Create a new script in root: `zour-dough-[new-sensor].py`.
- Follow the pattern of importing `machine`, initializing sensor, and running a loop.

**Shared Utilities:**
- Create a new module (e.g., `utils.py`) in root and import it into scripts if logic becomes complex.

**Firmware Updates:**
- Add new `.uf2` files to `firmware/` directory with version in filename.

## Special Directories

**firmware/:**
- Purpose: Binary storage for flashing microcontrollers.
- Generated: No (downloaded artifacts).
- Committed: Yes.

---

*Structure analysis: 2026-02-17*
