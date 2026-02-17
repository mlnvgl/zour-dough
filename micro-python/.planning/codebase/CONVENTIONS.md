# Coding Conventions

**Analysis Date:** 2026-02-17

## Naming Patterns

**Files:**
- Kebab-case with `.py` extension
- Examples: `zour-dough-dht22.py`, `zour-dough-ds18b20.py`

**Variables:**
- Snake_case for variables and instances
- Examples: `data_pin`, `heater_pin`, `temp_c`, `sensor`

**Constants:**
- SCREAMING_SNAKE_CASE for configuration values
- Examples: `MAX_TEMP`, `MIN_TEMP`, `CHECK_INTERVAL`

**Imports:**
- Standard MicroPython imports
- Examples: `import machine`, `import time`, `import dht`

## Code Style

**Formatting:**
- **Inconsistent indentation observed:**
  - `zour-dough-dht22.py`: Uses 4 spaces
  - `zour-dough-ds18b20.py`: Uses tabs
- Recommendation: Standardize on 4 spaces (PEP 8) for all Python files.

**String Formatting:**
- **Inconsistent approaches observed:**
  - f-strings: `f"Temperature: {temperature}°C"` (in `zour-dough-dht22.py`)
  - `.format()`: `"Found {} sensor(s)".format(len(roms))` (in `zour-dough-ds18b20.py`)
- Recommendation: Prefer f-strings for readability if supported by the target MicroPython version (usually yes for modern builds).

**Linting:**
- No linting configuration detected (e.g., `pylint`, `flake8`, `ruff`).
- Recommended: Add a basic linter configuration to catch syntax errors and style issues before uploading to the device.

## Import Organization

**Order:**
1. Hardware/System imports (`machine`, `time`, `ubinascii`)
2. Sensor/Protocol specific libraries (`dht`, `onewire`, `ds18x20`)

**Path Aliases:**
- None used (standard flat directory structure).

## Error Handling

**Patterns:**
- `try...except` blocks wrap the main execution loop to prevent the script from crashing and exiting.
- Errors are printed to the console (serial output).

**Examples:**
- specific exception: `except OSError as e:` (`zour-dough-dht22.py`)
- general exception: `except Exception as e:` (`zour-dough-ds18b20.py`)

**Recommendation:**
- Prefer specific exceptions (`OSError`, `RuntimeError`) over generic `Exception`.
- Consider logging errors to a file or flash if persistent logging is needed, otherwise `print` is acceptable for debugging.

## Hardware Interaction

**Pin Definition:**
- GPIO pins are defined at the top level with comments explaining their purpose.
- Example: `heater = Pin(12, Pin.OUT)  # MOSFET on GPIO 12`

**Timing:**
- `time.sleep()` used for main loop delays.
- `time.sleep_ms()` used for sensor-specific timing requirements (e.g., DS18B20 conversion time).

## Comments

**Usage:**
- Inline comments explain hardware connections (`# MOSFET on GPIO 12`).
- Comments explain configuration values (`# Celsius - turn heater off`).
- Logic sections are commented (`# Temperature control`).

---

*Convention analysis: 2026-02-17*
