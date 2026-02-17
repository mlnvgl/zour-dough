# Testing Patterns

**Analysis Date:** 2026-02-17

## Test Framework

**Runner:**
- No test runner detected (`pytest`, `unittest`, etc.).
- The project appears to rely on manual testing on the target hardware (Raspberry Pi Pico/ESP32).

**Recommendation:**
- Use `pytest` for local development and unit testing of logic that doesn't strictly depend on hardware.
- Use mocks for hardware interaction.

## Test File Organization

**Location:**
- No dedicated test directory (`tests/` or `test/`) exists.
- No test files (`test_*.py`) exist alongside source code.

**Recommendation:**
- Create a `tests/` directory at the project root.
- Add `test_dht22.py` and `test_ds18b20.py`.

## Mocking

**Framework:**
- Not currently used.

**Recommendation:**
- Use `unittest.mock` (standard library in Python 3, requires separate install for MicroPython or just mocking on host PC).
- Mock `machine.Pin`, `dht.DHT22`, `onewire.OneWire`, and `ds18x20.DS18X20` classes to simulate hardware responses.

**Example Mocking Strategy (for `pytest`):**
```python
import sys
from unittest.mock import MagicMock

# Mock modules before importing the script under test
sys.modules['machine'] = MagicMock()
sys.modules['dht'] = MagicMock()
sys.modules['time'] = MagicMock()

# Now import the script (if refactored into importable functions)
# import zour_dough_dht22
```

## Fixtures and Factories

**Test Data:**
- None.

**Recommendation:**
- Create fixtures for:
    - `mock_pin`: A mock pin object that tracks value changes (e.g., heater ON/OFF).
    - `mock_sensor`: A mock sensor that returns specific temperature/humidity values when `measure()` is called.

## Coverage

**Requirements:**
- None enforced.

**Recommendation:**
- Aim for high coverage of logic branches (e.g., temperature threshold checks) using mocks.
- Hardware interaction code (e.g., `sensor.measure()`) is harder to cover without integration tests on device.

## Test Types

**Unit Tests:**
- Not present.
- **Goal:** Verify logic for `if temperature >= MAX_TEMP:` and `elif temperature <= MIN_TEMP:` conditions.

**Integration Tests:**
- Currently performed manually by running the script on the device and observing serial output.

**E2E Tests:**
- Not applicable in the traditional web sense, but system validation involves running the firmware on the actual hardware in the target environment.

## Common Patterns (Proposed)

**Refactoring for Testability:**
- Currently, scripts run code at the top level (`while True:` loop).
- **Recommendation:** Refactor code into functions (e.g., `read_sensor()`, `control_heater(temp, heater_pin)`) to make them importable and testable without running the infinite loop.

```python
def control_heater(temp, heater_pin, max_temp, min_temp):
    if temp >= max_temp:
        heater_pin.value(0)
        return "OFF"
    elif temp <= min_temp:
        heater_pin.value(1)
        return "ON"
    return "NO_CHANGE"
```

---

*Testing analysis: 2026-02-17*
