# Project State: IoT Temperature Monitor

**Current Phase:** 2 - Core Firmware
**Status:** In Progress
**Plan:** Develop firmware for ESP32/Pico W to read sensor and publish to MQTT

## Context

**Core Value:**
Reliable, continuous temperature logging and visualization over multiple days without manual data handling.

**Current Focus:**
Now that the backend is running (Phase 1 complete), we need to feed it data. Phase 2 focuses on the device firmware: reading the sensor and publishing to the MQTT broker we just set up.

## Progress

| Phase | Status | Completion |
|-------|--------|------------|
| 1. Backend Infrastructure | **Complete** | 100% |
| 2. Core Firmware | **Active** | 80% |
| 3. Visualization | Planned | 0% |

## Recent Decisions
- **2026-02-27:** Removed DHT22 support to focus exclusively on DS18B20 sensor.
- **2026-02-27:** Integrated `mqtt_as` for robust asynchronous MQTT connectivity.
- **2026-02-27:** Updated DS18B20 script to use `uasyncio` and `mqtt_as`.
- **2026-02-19:** Verified backend stack with Docker Compose (Mosquitto, Telegraf, InfluxDB).
- **2026-02-19:** Validated data path: MQTT -> Telegraf -> InfluxDB.
- **2026-02-17:** Adopted 3-phase structure (Backend -> Firmware -> Vis) to validate data path early.

## Todo
- [x] Create `docker-compose.yml` for Mosquitto, InfluxDB, Grafana
- [x] Configure `telegraf.conf` to bridge MQTT -> InfluxDB
- [x] Verify local MQTT connection (via Telegraf logs)
- [x] Initialize firmware project (Phase 2)
- [x] Implement sensor reading code (DS18B20)
- [x] Implement MQTT publishing with `mqtt_as`
- [ ] Test firmware on actual hardware (User Verification)

## Blockers
- None currently.
