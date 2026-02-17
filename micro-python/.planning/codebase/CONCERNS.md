# Codebase Concerns

**Analysis Date:** 2026-02-17

## Tech Debt

**Hardcoded Configuration:**
- Issue: GPIO pins, temperature thresholds, and timing intervals are hardcoded directly in script files.
- Files: `zour-dough-ds18b20.py`, `zour-dough-dht22.py`
- Impact: Changing hardware setup requires modifying code. Inconsistent configurations across scripts (e.g., heater on Pin 21 vs Pin 12).
- Fix approach: Move configuration to a separate `config.py` or JSON file.

**Code Duplication:**
- Issue: Temperature control logic (hysteresis loop) is copy-pasted between scripts.
- Files: `zour-dough-ds18b20.py`, `zour-dough-dht22.py`
- Impact: Bug fixes or improvements to control logic must be applied twice.
- Fix approach: Create a shared `TemperatureController` class in a utility module.

**Missing Entry Points:**
- Issue: No `main.py` or `boot.py` exists to run code automatically on startup.
- Files: `.`
- Impact: Scripts must be manually executed via REPL or IDE.
- Fix approach: Create a `main.py` that imports/runs the desired logic based on config.

## Known Bugs

**Heater Logic Conflict (Multiple Sensors):**
- Symptoms: Heater toggles rapidly or ends up in wrong state if multiple DS18B20 sensors are connected.
- Files: `zour-dough-ds18b20.py`
- Trigger: The script iterates through `roms` list. If one sensor reads > MAX and another reads < MIN in the same loop, the heater state will flip-flop, with the last sensor in the list determining the final state.
- Workaround: Ensure only one sensor is connected.

**Pin Inconsistency:**
- Symptoms: Heater may not work if switching between scripts without rewiring.
- Files: `zour-dough-ds18b20.py` (Heater on Pin 21), `zour-dough-dht22.py` (Heater on Pin 12).
- Trigger: Running different scripts on the same hardware board.
- Workaround: Manually check and update pin numbers before running.

## Security Considerations

**Input Validation:**
- Risk: None currently (no user input).
- Note: If network/web interface is added, input validation for configuration will be needed.

## Performance Bottlenecks

**Blocking Execution:**
- Problem: `time.sleep()` halts the entire processor.
- Files: `zour-dough-ds18b20.py`, `zour-dough-dht22.py`
- Cause: Simple `sleep` usage instead of `uasyncio` or timer-based scheduling.
- Improvement path: Refactor to use `uasyncio` for non-blocking operation, allowing future addition of network/UI tasks.

## Fragile Areas

**Heater Fail-Safe:**
- Files: `zour-dough-ds18b20.py`, `zour-dough-dht22.py`
- Why fragile: If the sensor fails (disconnects, error), the script catches the exception but the heater remains in its *last known state*.
- Risk: If heater was ON when sensor failed, it stays ON indefinitely, potentially causing overheating/fire hazard.
- Safe modification: Add a `finally` block or error handler to turn heater OFF explicitly when sensor reads fail for a certain duration.

**Sensor Initialization:**
- Files: `zour-dough-ds18b20.py`
- Why fragile: `ds.scan()` only runs once at startup.
- Risk: Sensors plugged in after boot are ignored. Hot-swapping requires reboot.

## Missing Critical Features

**Watchdog Timer:**
- Problem: No `WDT` usage.
- Blocks: Automatic recovery from system hangs or crashes.

**Logging/Telemetry:**
- Problem: Only `print()` to serial console.
- Blocks: Debugging issues that happen when not connected to a computer.

---

*Concerns audit: 2026-02-17*
