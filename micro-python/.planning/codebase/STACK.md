# Technology Stack

**Analysis Date:** 2026-02-17

## Languages

**Primary:**
- Python (MicroPython) 3.x - Used for all logic in `*.py` files

## Runtime

**Environment:**
- MicroPython Firmware - Running on Raspberry Pi Pico 2 (RP2350)
  - Firmware files: `firmware/*.uf2`

**Package Manager:**
- None (Standard MicroPython libraries used)

## Frameworks

**Core:**
- MicroPython Standard Library - Provides hardware access (`machine`, `time`, `dht`, `onewire`, `ds18x20`)

**Testing:**
- None detected

**Build/Dev:**
- Thonny IDE - Recommended for development and flashing

## Key Dependencies

**Hardware Libraries (Built-in):**
- `machine` - GPIO control
- `dht` - DHT22 sensor driver
- `onewire` & `ds18x20` - DS18B20 sensor driver
- `time` - Delays and timing

## Configuration

**Environment:**
- Hardcoded constants in Python files
- Key configs: `MAX_TEMP`, `MIN_TEMP`, `CHECK_INTERVAL`, Pin assignments

**Build:**
- No build process (Interpreted)

## Platform Requirements

**Development:**
- USB connection to RP2350
- Serial monitor (e.g., Thonny, screen, minicom)

**Production:**
- Raspberry Pi Pico 2 (RP2350)
- Power supply via USB or VSYS

---

*Stack analysis: 2026-02-17*
