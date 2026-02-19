# IoT Temperature Monitor

## What This Is
A MicroPython-based temperature monitoring system that logs data from a DS18B20 sensor over WiFi to a local Docker-based IoT stack (Mosquitto, InfluxDB, Grafana). It enables long-term visualization of temperature trends on a PC/Laptop.

## Core Value
Reliable, continuous temperature logging and visualization over multiple days without manual data handling.

## Requirements

### Validated
(None yet — ship to validate)

### Active
- [ ] **Device:** Read temperature from DS18B20 sensor
- [ ] **Device:** Connect reliably to WiFi (auto-reconnect)
- [ ] **Device:** Publish readings to MQTT broker
- [ ] **Backend:** Run MQTT broker (Mosquitto) via Docker
- [ ] **Backend:** Store time-series data (InfluxDB) via Docker
- [ ] **Backend:** Visualize temperature history (Grafana) via Docker
- [ ] **System:** Bridge MQTT data to InfluxDB (Telegraf or script)

### Out of Scope
- [Mobile App] — Focus on PC-based dashboard for now
- [Cloud Hosting] — Local Docker stack preferred for privacy/cost
- [DHT22 Support] — Focused on DS18B20 per user request

## Context
- **Hardware:** ESP32/ESP8266 (implied by MicroPython), DS18B20 sensor
- **Existing Code:** `zour-dough-ds18b20.py` (sensor test script)
- **Environment:** PC/Laptop capable of running Docker containers

## Constraints
- **Connectivity:** Requires stable WiFi connection
- **Power:** Device must be powered continuously (USB/Wall)
- **Resources:** MicroPython memory limits (use lightweight MQTT client)

## Key Decisions
| Decision | Rationale | Outcome |
|----------|-----------|---------|
| MQTT Transport | Lightweight, standard IoT protocol, decouples device from storage | — Pending |
| Docker Stack | Simplifies deployment of Mosquitto/InfluxDB/Grafana on PC | — Pending |
| InfluxDB | Specialized time-series DB for sensor data | — Pending |

---
*Last updated: 2026-02-17 after initialization*
