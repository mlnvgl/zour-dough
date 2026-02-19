# Requirements: IoT Temperature Monitor

**Defined:** 2026-02-17
**Core Value:** Reliable, continuous temperature logging and visualization over multiple days.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Device Firmware

- [ ] **FIRM-01**: Device can read temperature from DS18B20 sensor (async non-blocking)
- [ ] **FIRM-02**: Device connects reliably to WiFi and MQTT using `mqtt_as` (auto-reconnect)
- [ ] **FIRM-03**: Device publishes temperature data as JSON to MQTT topic
- [ ] **FIRM-04**: Device verifies DS18B20 sensor authenticity on startup (anti-counterfeit check)
- [ ] **FIRM-05**: Device configuration (WiFi/MQTT) is read from `secrets.py`

### Backend Infrastructure

- [ ] **BACK-01**: Mosquitto MQTT broker runs in Docker
- [ ] **BACK-02**: InfluxDB v2 runs in Docker for time-series storage
- [ ] **BACK-03**: Telegraf runs in Docker to bridge MQTT messages to InfluxDB
- [ ] **BACK-04**: Docker Compose file orchestrates the full stack

### Visualization

- [ ] **VIS-01**: Grafana runs in Docker and connects to InfluxDB v2 source
- [ ] **VIS-02**: Dashboard displays current temperature gauge
- [ ] **VIS-03**: Dashboard displays historical temperature graph (configurable time range)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Configuration
- **CONF-01**: Captive portal for WiFi/MQTT credential configuration
- **CONF-02**: Web interface for viewing device status

### Advanced Dashboard
- **VIS-04**: Configurable alerts (Email/Telegram) for temperature thresholds
- **VIS-05**: Min/Max/Average statistics for selected period

### Power
- **PWR-01**: Deep sleep support for battery operation

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Mobile App | Focus on PC/Laptop Docker dashboard for v1 |
| Cloud Hosting | Local Docker stack preferred for privacy/cost |
| DHT22 Support | Focused on DS18B20 per user request |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BACK-01 | Phase 1 | Pending |
| BACK-02 | Phase 1 | Pending |
| BACK-03 | Phase 1 | Pending |
| BACK-04 | Phase 1 | Pending |
| FIRM-01 | Phase 2 | Pending |
| FIRM-02 | Phase 2 | Pending |
| FIRM-03 | Phase 2 | Pending |
| FIRM-04 | Phase 2 | Pending |
| FIRM-05 | Phase 2 | Pending |
| VIS-01 | Phase 3 | Pending |
| VIS-02 | Phase 3 | Pending |
| VIS-03 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0 ✓

---
*Requirements defined: 2026-02-17*
*Last updated: 2026-02-17 after roadmap creation*
