# Phase 01: Backend Infrastructure (TIG Stack) - Research

**Researched:** 2026-02-19
**Domain:** Backend Infrastructure / IoT Data Ingestion
**Confidence:** HIGH

## Summary

This phase establishes the foundational backend infrastructure using the "TIG" stack (Telegraf, InfluxDB, Grafana) approach, specifically focusing on Mosquitto, InfluxDB v2, and Telegraf for this initial step. The goal is to create a containerized environment where MQTT messages are received by Mosquitto, consumed by Telegraf, and persisted into InfluxDB v2.

The research confirms that official Docker images are available and well-documented for all components. The primary complexity lies in the configuration of Mosquitto 2.0+ (which defaults to secure-only) and InfluxDB v2 (which requires token-based authentication and organization/bucket initialization).

**Primary recommendation:** Use a `docker-compose.yml` with official images, utilizing environment variables for InfluxDB initialization and a custom `mosquitto.conf` to permit external connections.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `eclipse-mosquitto` | `2.0` | MQTT Broker | Official Eclipse image, industry standard. |
| `influxdb` | `2.7` | Time-series DB | Official image. v2 is the current standard (v1 is legacy). |
| `telegraf` | `1.29+` | Data Collector | Official plugin-driven agent for InfluxDB. |
| `docker` & `compose` | Recent | Orchestration | Requirement for the project. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `influxdb-client` | CLI | Debugging | Useful for verifying data inside the container. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `telegraf` | Custom Python Script | Custom scripts are brittle and require maintenance. Telegraf is config-driven and high-performance. |
| `mosquitto` | `emqx` / `hivemq` | Mosquitto is lightweight and sufficient for this scale. Others are overkill. |
| `influxdb:2` | `influxdb:1.8` | v1 is easier to setup but deprecated. v2 has better auth/org features. |

## Architecture Patterns

### Recommended Project Structure
```
backend/
├── mosquitto/
│   └── config/
│       └── mosquitto.conf
├── telegraf/
│   └── telegraf.conf
├── docker-compose.yml
└── .env
```

### Pattern 1: Container Orchestration
**What:** Use Docker Compose to define services and networking.
**When to use:** Always for multi-container local development.
**Example:**
```yaml
services:
  mosquitto:
    image: eclipse-mosquitto:2.0
    ports:
      - "1883:1883"
    volumes:
      - ./mosquitto/config:/mosquitto/config
      - mosquitto-data:/mosquitto/data

  influxdb:
    image: influxdb:2.7
    ports:
      - "8086:8086"
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=admin
      - DOCKER_INFLUXDB_INIT_PASSWORD=password123
      - DOCKER_INFLUXDB_INIT_ORG=myorg
      - DOCKER_INFLUXDB_INIT_BUCKET=mybucket
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=my-super-secret-token
    volumes:
      - influxdb-data:/var/lib/influxdb2

  telegraf:
    image: telegraf:1.29
    volumes:
      - ./telegraf/telegraf.conf:/etc/telegraf/telegraf.conf:ro
    depends_on:
      - influxdb
      - mosquitto
```

### Pattern 2: MQTT to InfluxDB Bridge
**What:** Telegraf acts as the consumer of MQTT topics and the producer for InfluxDB.
**When to use:** To decouple the broker from the database.
**Key Config (`telegraf.conf`):**
```toml
[[inputs.mqtt_consumer]]
  servers = ["tcp://mosquitto:1883"]
  topics = ["#"]
  data_format = "influx" # For manual testing with line protocol

[[outputs.influxdb_v2]]
  urls = ["http://influxdb:8086"]
  token = "$DOCKER_INFLUXDB_INIT_ADMIN_TOKEN" # Passed via env var to container
  organization = "myorg"
  bucket = "mybucket"
```

### Anti-Patterns to Avoid
- **Hardcoding Secrets:** Do not hardcode the InfluxDB token in `telegraf.conf`. Pass it as an environment variable to the Telegraf container.
- **Mosquitto `latest`:** Version 2.0 introduced breaking changes to default security. Pin to `2.0` and configure explicitly.
- **Root-owned Volumes:** Docker often creates volumes as root. Ensure correct permissions if mapping to host folders (using named volumes avoids this mostly).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MQTT -> DB | Custom Python/Node script | `telegraf` | Handles reconnection, batching, buffering, and protocol parsing out of the box. |
| DB Init | Manual `curl` commands | `DOCKER_INFLUXDB_INIT_*` | The official image handles setup scripts automatically. |

## Common Pitfalls

### Pitfall 1: Mosquitto 2.0+ Connections Rejected
**What goes wrong:** Clients cannot connect; logs show "Connection Refused" or silent drops.
**Why it happens:** Mosquitto 2.0+ defaults to listening only on `localhost` and requires authentication.
**How to avoid:**
Create `mosquitto/config/mosquitto.conf` with:
```
listener 1883
allow_anonymous true
```
**Warning signs:** `docker logs mosquitto` shows "Starting in local only mode".

### Pitfall 2: InfluxDB v2 Token Auth
**What goes wrong:** Telegraf gets `401 Unauthorized`.
**Why it happens:** Telegraf config doesn't match the initialization token of InfluxDB.
**How to avoid:** Explicitly set `DOCKER_INFLUXDB_INIT_ADMIN_TOKEN` in `docker-compose.yml` and pass that same token to Telegraf.

### Pitfall 3: Telegraf MQTT Data Format
**What goes wrong:** Messages arrive in MQTT but don't appear in InfluxDB.
**Why it happens:** Telegraf cannot parse the payload. `data_format = "influx"` expects valid Line Protocol. `data_format = "json"` expects JSON.
**How to avoid:** For Phase 1 (Manual testing), use `data_format = "influx"` and send raw line protocol strings (e.g., `temp,sensor=1 value=25.5`).

## Code Examples

### Mosquitto Config (`mosquitto.conf`)
```
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
listener 1883
allow_anonymous true
```

### Telegraf Config (`telegraf.conf`)
```toml
[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  debug = true # Helpful for Phase 1

[[inputs.mqtt_consumer]]
  servers = ["tcp://mosquitto:1883"]
  topics = ["sensors/#"]
  data_format = "influx"

[[outputs.influxdb_v2]]
  urls = ["http://influxdb:8086"]
  token = "${INFLUX_TOKEN}"
  organization = "zour_dough"
  bucket = "sensors"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| InfluxDB v1 (Database/User) | InfluxDB v2 (Org/Bucket/Token) | 2020 (v2 release) | Better security, Flux language, unified API. |
| Custom Bridges | Telegraf Plugins | ~2015 | Standardization, reliability. |

## Open Questions

1.  **Retention Policy:** What should the default retention policy be? (Start with infinite for dev, refine later).
2.  **Schema Design:** What specific tags/fields will the firmware send? (To be decided in Phase 2, but `data_format = "influx"` allows flexibility now).

## Sources

### Primary (HIGH confidence)
- Docker Hub: `eclipse-mosquitto` - Verified 2.0 config requirements.
- Docker Hub: `influxdb` - Verified initialization env vars.
- Docker Hub: `telegraf` - Verified plugin existence.

### Secondary (MEDIUM confidence)
- InfluxData Docs: Telegraf MQTT Consumer Plugin.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Industry standard IoT stack.
- Architecture: HIGH - Standard container pattern.
- Pitfalls: HIGH - Well-known issues with v2 migrations and Mosquitto security updates.

**Research date:** 2026-02-19
**Valid until:** 2026-08-19
