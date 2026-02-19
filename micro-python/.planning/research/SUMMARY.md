# Project Research Summary

**Project:** IoT Temperature Monitor
**Domain:** IoT / Embedded Systems
**Researched:** Tue Feb 17 2026
**Confidence:** HIGH

## Executive Summary

This project is a classic IoT temperature monitoring system utilizing MicroPython on ESP8266/ESP32 microcontrollers with DS18B20 sensors. The industry-standard approach for this stack involves a "headless" edge device that publishes JSON data via MQTT to a centralized backend. This architecture decouples data acquisition from storage and visualization, ensuring robustness and scalability. The research strongly advises against custom "mega-loops" or direct database writes from the microcontroller, favoring an asynchronous, non-blocking design using `uasyncio` and `mqtt_as`.

The recommended stack is a modern, open-source integration of MicroPython v1.24+, Mosquitto (MQTT Broker), Telegraf (Data Bridge), InfluxDB v2 (Time-Series DB), and Grafana (Visualization). This combination minimizes custom coding on the backend and leverages robust, purpose-built tools for data routing and storage. The critical path involves setting up the infrastructure first, then developing the firmware to match the data contract.

Key risks center on hardware and network reliability. "Counterfeit" DS18B20 sensors are a major pitfall, causing erratic readings or failure. On the software side, blocking network calls in the firmware is the primary cause of device instability. Mitigations include sourcing genuine sensors, implementing `uasyncio` for non-blocking operations, and using the `mqtt_as` library to handle connection resilience automatically.

## Key Findings

### Recommended Stack

**Core technologies:**
- **MicroPython (v1.24+)**: Firmware — Standard Python implementation for MCUs; `v1.24` has critical `asyncio` fixes.
- **mqtt_as**: MQTT Client — **Critical** library that handles async WiFi/MQTT reconnection better than standard `umqtt`.
- **InfluxDB v2 + Telegraf**: Storage & Ingestion — Modern standard for time-series data; Telegraf handles buffering and parsing (JSON -> Line Protocol).
- **Grafana**: Visualization — Richer dashboards than InfluxDB UI; native support for Flux queries.
- **Mosquitto**: Broker — Lightweight, secure-by-default industry standard.

### Expected Features

**Must have (table stakes):**
- **WiFi Auto-Reconnect** — Device must recover from router reboots without manual intervention.
- **Reliable Sensor Reading** — Accurate temp conversion (handling 750ms delay) and CRC checks.
- **MQTT Publishing** — Sending data as JSON payloads to a broker.
- **Watchdog Timer** — Self-recovery from freezes.

**Should have (competitive):**
- **Asynchronous Loop** — Uses `uasyncio` to remain responsive during sensor delays.
- **Device Health Telemetry** — Reports RSSI, RAM, and Uptime for debugging.
- **Config via `config.json`** — Separation of credentials from code.

**Defer (v2+):**
- **Captive Portal** — High complexity for MVP; use `config.json` instead.
- **Offline Buffering** — Requires NTP sync and complex RAM management.
- **OTA Updates** — Complex infrastructure requirement.

### Architecture Approach

The system follows a **Publisher-Subscriber (Pub/Sub)** pattern with an **Asyncio-First** design on the edge.

**Major components:**
1.  **Edge Device (MicroPython)** — Reads sensors non-blockingly, publishes JSON to MQTT.
2.  **Ingestion Pipeline (Mosquitto + Telegraf)** — Routes messages and transforms JSON to InfluxDB Line Protocol.
3.  **Data Platform (InfluxDB + Grafana)** — Stores time-series data and renders dashboards.

### Critical Pitfalls

1.  **The "Counterfeit DS18B20" Trap** — Fakes fail in parasitic mode and drift. **Avoid:** Buy from authorized distributors; use 3-wire mode.
2.  **Blocking Network Loops** — `time.sleep()` freezes the CPU, causing MQTT disconnects. **Avoid:** Use `uasyncio` and `mqtt_as`.
3.  **Flash Wearout** — Logging to local files destroys the flash memory. **Avoid:** Send data to MQTT; buffer in RAM only if necessary.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Infrastructure & Backend
**Rationale:** You need a place to send data before you can test the device. Docker containers are easier to fix than firmware.
**Delivers:** Running Mosquitto, InfluxDB, Telegraf, and Grafana via Docker Compose.
**Addresses:** Backend stability and data schema definition.
**Avoids:** "Coding in the dark" (writing firmware without a working server).

### Phase 2: Hardware Validation & Hello World
**Rationale:** Verify the physical layer before complex logic. Counterfeit sensors are a high risk.
**Delivers:** A simple script reading the sensor and printing to REPL.
**Uses:** `ds18x20` driver, `onewire`.
**Avoids:** **Pitfall 1 (Counterfeit Sensors)** — fail fast if hardware is bad.

### Phase 3: Firmware Core (Connectivity)
**Rationale:** Establishing a reliable connection is the hardest part of IoT.
**Delivers:** MicroPython firmware with `mqtt_as` connecting to WiFi/MQTT and handling disconnects.
**Uses:** `mqtt_as`, `uasyncio`, `config.json`.
**Avoids:** **Pitfall 2 (Blocking Loops)** by implementing async patterns early.

### Phase 4: Integration & Telemetry
**Rationale:** Combine sensor data with connectivity.
**Delivers:** Full loop: Read Sensor -> Format JSON -> Publish -> Visualize in Grafana.
**Implements:** The full Data Flow architecture.
**Avoids:** **Pitfall 3 (Flash Wearout)** by ensuring data goes to MQTT, not local files.

### Phase Ordering Rationale

- **Backend First:** Defines the contract (Topic names, JSON structure) that firmware must satisfy.
- **Hardware Second:** Isolates physical issues from software bugs.
- **Connectivity Third:** Solves the hardest software problem (async networking) in isolation.
- **Integration Last:** Merges proven components.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 4:** Need to verify specific InfluxDB Flux queries for the dashboard if new to Flux language.

Phases with standard patterns (skip research-phase):
- **Phase 1:** Docker Compose stacks for this are standard.
- **Phase 2 & 3:** The `mqtt_as` library and `ds18x20` drivers are well-documented standards.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Libraries (`mqtt_as`, `micropython`) are mature and standard. |
| Features | HIGH | Table stakes are clear for this domain. |
| Architecture | HIGH | Pub/Sub is the de-facto standard for IoT. |
| Pitfalls | HIGH | Counterfeit sensor issue is well-documented in community. |

**Overall confidence:** HIGH

### Gaps to Address

- **Deep Sleep Strategy:** Research touches on it but suggests `mqtt_as` (always on) vs `umqtt.simple` (deep sleep) are mutually exclusive. Decision needed: is this battery or mains powered? (Assumed mains for "Monitor" default).
- **Specific Telegraf Config:** Exact `inputs.mqtt_consumer` config needs to match the JSON structure defined in firmware.

## Sources

### Primary (HIGH confidence)
- **Peter Hinch's mqtt_as** — The gold standard for MicroPython MQTT resilience.
- **MicroPython Docs** — Verified `uasyncio` and `onewire` library status.
- **InfluxData Docs** — Verified v2 OSS status and Telegraf integration patterns.

### Secondary (MEDIUM confidence)
- **Community Forums** — Consensus on counterfeit DS18B20 prevalence.

---
*Research completed: Tue Feb 17 2026*
*Ready for roadmap: yes*
