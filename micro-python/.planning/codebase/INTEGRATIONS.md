# External Integrations

**Analysis Date:** 2026-02-17

## APIs & External Services

**None:**
- No external HTTP APIs or cloud services detected.

## Data Storage

**Databases:**
- None. Data is printed to console (`print()`) and not persisted.

**File Storage:**
- None.

**Caching:**
- None.

## Authentication & Identity

**Auth Provider:**
- None. No authentication required for serial console access.

## Monitoring & Observability

**Error Tracking:**
- None. Exceptions are caught and printed to console.

**Logs:**
- Serial Output (USB/UART): All sensor readings and status messages are printed to `stdout`.

## CI/CD & Deployment

**Hosting:**
- Local Embedded Device (Raspberry Pi Pico 2).

**CI Pipeline:**
- None.

## Environment Configuration

**Required env vars:**
- None. Configuration is hardcoded in `zour-dough-dht22.py` and `zour-dough-ds18b20.py`.

**Secrets location:**
- Not applicable.

## Hardware Interfaces

**Sensors:**
- DHT22 (Temperature/Humidity) - GPIO 22 (`zour-dough-dht22.py`)
- DS18B20 (Temperature) - OneWire on GPIO 22 (`zour-dough-ds18b20.py`)

**Actuators:**
- Heater Control (MOSFET) - GPIO 12 (`zour-dough-dht22.py`) or GPIO 21 (`zour-dough-ds18b20.py`)

---

*Integration audit: 2026-02-17*
