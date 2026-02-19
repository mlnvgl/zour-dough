# Project State: IoT Temperature Monitor

**Current Phase:** 1 - Backend Infrastructure
**Status:** In Progress
**Plan:** Setup TIG (Telegraf, InfluxDB, Grafana) Stack in Docker

## Context

**Core Value:**
Reliable, continuous temperature logging and visualization over multiple days without manual data handling.

**Current Focus:**
Establishing the data destination first. We need a working MQTT broker and InfluxDB to receive data before we write any firmware. This avoids "coding in the dark."

## Progress

| Phase | Status | Completion |
|-------|--------|------------|
| 1. Backend Infrastructure | **Active** | 0% |
| 2. Core Firmware | Planned | 0% |
| 3. Visualization | Planned | 0% |

## Recent Decisions
- **2026-02-17:** Adopted 3-phase structure (Backend -> Firmware -> Vis) to validate data path early.
- **2026-02-17:** Using `mqtt_as` for robust async connectivity in Phase 2.

## Todo
- [ ] Create `docker-compose.yml` for Mosquitto, InfluxDB, Grafana
- [ ] Configure `telegraf.conf` to bridge MQTT -> InfluxDB
- [ ] Verify local MQTT connection with desktop client

## Blockers
- None currently.
