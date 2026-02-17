# Architecture

**Analysis Date:** 2026-02-17

## Pattern Overview

**Overall:** Embedded Control Loop (Polling)

**Key Characteristics:**
- Infinite `while True` loop execution model
- Direct hardware interaction via GPIO
- Synchronous, blocking sensor reads with sleep intervals

## Layers

**Hardware Abstraction Layer:**
- Purpose: Interface with physical sensors and actuators
- Location: `machine` module imports, `dht`, `ds18x20`, `onewire` libraries
- Contains: Pin definitions, sensor initialization
- Depends on: MicroPython runtime
- Used by: Control Logic

**Control Logic:**
- Purpose: Compare sensor readings against defined thresholds
- Location: Main loop in scripts like `zour-dough-ds18b20.py`
- Contains: Threshold constants (`MAX_TEMP`, `MIN_TEMP`), conditional logic
- Depends on: Hardware Abstraction Layer

**Presentation/Debug:**
- Purpose: Output status to serial console
- Location: `print()` statements within loops
- Contains: Formatted strings with sensor data

## Data Flow

**Temperature Control Loop:**

1. **Acquire:** Read sensor data (Temperature/Humidity) from `dht` or `ds18x20` sensor.
2. **Evaluate:** Compare current temperature against `MAX_TEMP` and `MIN_TEMP`.
3. **Act:** Toggle Heater Pin (`High`/`Low`) based on evaluation.
4. **Wait:** Sleep for `CHECK_INTERVAL`.

**State Management:**
- Stateless execution flow; each iteration is independent.
- Ephemeral state: Current temperature `temp_c`, humidity `humidity`.
- Hardware state: Heater GPIO pin value (0 or 1).

## Key Abstractions

**Hardware Interfaces:**
- Purpose: Represents physical pins and protocols
- Examples: `machine.Pin`, `onewire.OneWire`
- Pattern: Object-oriented hardware wrappers

**Sensor Drivers:**
- Purpose: Encapsulate protocol-specific communication logic
- Examples: `dht.DHT22`, `ds18x20.DS18X20`
- Pattern: Driver instantiation with hardware pin dependency injection

## Entry Points

**Script Execution:**
- Location: `zour-dough-ds18b20.py` or `zour-dough-dht22.py`
- Triggers: Manual execution or `main.py` (if configured for auto-start)
- Responsibilities: Initialize hardware, start infinite control loop

## Error Handling

**Strategy:** Global Exception Catching within Loop

**Patterns:**
- `try...except` blocks wrapping the main loop logic to prevent crash on sensor read failure.
- Prints error message to console and continues to next iteration.
- Example:
  ```python
  try:
      # logic
  except Exception as e:
      print("Error: {}".format(e))
  ```

## Cross-Cutting Concerns

**Logging:**
- Approach: `print()` to standard output (Serial/REPL).
- No persistent logging implemented.

**Configuration:**
- Approach: Hardcoded constants at top of file (`MAX_TEMP`, `PIN` numbers).

---

*Architecture analysis: 2026-02-17*
