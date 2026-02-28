# Roadmap: IoT Temperature Monitor

**Overview:**
A 3-phase delivery path to build a reliable MicroPython temperature monitor. Focuses on establishing the data destination first (Backend), then the data source (Firmware), and finally connecting them (Visualization).

**Depth:** Quick (3 phases)
**Status:** Active
**Progress:** 0/12 Requirements

## Phase 1: Backend Infrastructure (TIG Stack)

**Goal:** Users can successfully ingest manual MQTT messages into InfluxDB via a Dockerized stack.

**Status:** Complete (2026-02-19)
**Plans:** 1/1 complete

**Requirements:**
- **BACK-01**: Mosquitto MQTT broker runs in Docker
- **BACK-02**: InfluxDB v2 runs in Docker for time-series storage
- **BACK-03**: Telegraf runs in Docker to bridge MQTT messages to InfluxDB
- **BACK-04**: Docker Compose file orchestrates the full stack

**Success Criteria (Goal-Backward):**
1. User can connect to the local MQTT broker using a desktop client (e.g., MQTT Explorer).
2. User can access the InfluxDB web interface on localhost.
3. User can publish a manual JSON message to MQTT and see it appear in an InfluxDB bucket.
4. All containers spin up successfully with a single `docker-compose up` command.

## Phase 2: Core Firmware (Connectivity & Sensor)

**Goal:** Device reliably reads real-world temperature and publishes it to the broker, surviving network interruptions.

**Rationale:** Solves the hardest embedded challenges (async networking, sensor validation) in isolation before end-to-end integration.

**Dependencies:** Phase 1 (Working Broker)

**Requirements:**
- **FIRM-01**: Device can read temperature from DS18B20 sensor (async non-blocking)
- **FIRM-02**: Device connects reliably to WiFi and MQTT using `mqtt_as` (auto-reconnect)
- **FIRM-03**: Device publishes temperature data as JSON to MQTT topic
- **FIRM-04**: Device verifies DS18B20 sensor authenticity on startup (anti-counterfeit check)
- **FIRM-05**: Device configuration (WiFi/MQTT) is read from `secrets.py`

**Success Criteria (Goal-Backward):**
1. Device automatically reconnects to WiFi/MQTT after a simulated router reboot (power cycle router).
2. Device publishes valid JSON temperature data to the broker at a fixed interval.
3. Device reports a specific error if the sensor is disconnected or detected as counterfeit.
4. User can update WiFi credentials in `secrets.py` without modifying code logic.

## Phase 3: Visualization & Integration

**Goal:** Users can view live and historical temperature trends on a persistent dashboard.

**Rationale:** Completes the loop by turning raw data into actionable visual information.

**Dependencies:** Phase 2 (Live Data Stream)

**Requirements:**
- **VIS-01**: Grafana runs in Docker and connects to InfluxDB v2 source
- **VIS-02**: Dashboard displays current temperature gauge
- **VIS-03**: Dashboard displays historical temperature graph (configurable time range)

**Success Criteria (Goal-Backward):**
1. Grafana dashboard displays the current temperature reading within 5 seconds of device publication.
2. User can view a historical graph of temperature data over the last 24 hours.
3. Dashboard persists and reloads data correctly after a Docker container restart.

**Plans:** 1 plan
- [ ] 03-01-PLAN.md — Deploy Grafana & Dashboards

## Progress

| Phase | Status | Requirements |
|-------|--------|--------------|
| 1. Backend Infrastructure | **Planned** | BACK-01, BACK-02, BACK-03, BACK-04 |
| 2. Core Firmware | **Planned** | FIRM-01, FIRM-02, FIRM-03, FIRM-04, FIRM-05 |
| 3. Visualization | **Planned** | VIS-01, VIS-02, VIS-03 |
