# Stack Research

**Domain:** IoT Temperature Monitor (MicroPython)
**Researched:** Tue Feb 17 2026
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **MicroPython** | v1.24+ | Firmware | The standard Python implementation for microcontrollers. `v1.24` includes significant `asyncio` improvements critical for network stability. |
| **mqtt_as** | Latest (Peter Hinch) | MQTT Client | **Critical Choice.** Superior to `umqtt.robust` because it handles both WiFi and MQTT reconnection automatically using `asyncio`. Essential for 2025/2026 reliability. |
| **InfluxDB** | v2.7 (OSS) | Time Series DB | Current stable OSS standard. Offers Flux query language, built-in dashboards, and better security (tokens) than v1. |
| **Telegraf** | v1.32+ | Data Bridge | The "glue" between MQTT and InfluxDB. Handles buffering, batching, and retries natively, avoiding fragile custom scripts. |
| **Grafana** | v11.4+ (OSS) | Visualization | Industry standard for dashboards. Native support for InfluxDB (Flux) and richer visualization capabilities than InfluxDB UI. |
| **Eclipse Mosquitto** | v2.0+ | MQTT Broker | Lightweight, industry-standard broker. v2.0+ is secure by default (requires config for external access). |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **uasyncio** | Built-in | Concurrency | **Always.** Modern MicroPython standard for handling network tasks non-blockingly. |
| **ds18x20** | Built-in | Sensor Driver | **Always.** Standard, optimized driver for DS18B20 temperature sensors. |
| **onewire** | Built-in | Bus Protocol | **Always.** Required by `ds18x20`. |
| **ntptime** | Built-in | Time Sync | **Always.** To sync RTC on boot so logs have correct timestamps if the device buffers data. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **Docker Compose** | Infrastructure Orchestration | Essential for running the backend stack (Mosquitto, InfluxDB, Grafana, Telegraf) consistently. |
| **mpremote** | CLI Tool | Official MicroPython tool for flashing, REPL access, and file management. Replaces older tools like `ampy`. |
| **MicroPython Stubber** | IntelliSense | Generates stubs for VSCode to provide autocompletion for built-in modules. |

## Installation

```bash
# MicroPython (on device)
# Use mip to install mqtt_as if available, or copy manually
import mip
mip.install("github:peterhinch/micropython-mqtt/mqtt_as")

# Backend (Docker)
docker compose up -d
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| **mqtt_as** (Async) | `umqtt.robust` | If you cannot use `asyncio` for some reason (rare in 2025) or have extreme memory constraints on an old ESP8266. |
| **InfluxDB v2** | InfluxDB v1.8 | If you have legacy systems that only speak InfluxQL and cannot use the v1 compatibility API of v2. |
| **Telegraf** | Custom Python Script | If you need complex data transformation *before* storage that Telegraf processors cannot handle (rare). |
| **Mosquitto** | EMQX / HiveMQ | If you need massive clustering or enterprise features. Mosquitto is sufficient for home/SMB. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **DHT11/DHT22** | Unreliable, slow, and prone to self-heating/humidity drift. | **DS18B20** (for temp) or **BME280** (for temp/humidity). |
| **umqtt.simple** (raw) | No reconnection logic. Any network blip crashes the app. | **mqtt_as** or at least `umqtt.robust`. |
| **InfluxDB v1.x** | Effectively EOL for new features. Weaker security model. | **InfluxDB v2.x**. |
| **Blocking Sockets** | Pauses execution during network calls, ruining sensor timing. | **asyncio** + non-blocking sockets. |

## Stack Patterns by Variant

**If High Reliability is Required:**
- Use **mqtt_as** with a "clean session = False" (persistent session).
- Because it ensures messages queued by the broker during WiFi disconnects are delivered when reconnected.

**If Low Power (Battery) is Required:**
- Use **Deep Sleep** + **umqtt.simple** (connect, publish, sleep).
- Because `asyncio` and `mqtt_as` are designed for "always on" connection maintenance, which drains battery. For battery, you want to wake up, blast data, and die.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| **Telegraf v1.32** | **InfluxDB v2.7** | Use `outputs.influxdb_v2` plugin with `token`, `bucket`, and `organization` config. |
| **MicroPython v1.20+** | **mqtt_as** | `mqtt_as` relies on recent `asyncio` primitives found in newer MicroPython versions. |
| **Grafana v11** | **InfluxDB v2.7** | Use the "InfluxDB" data source with "Flux" language selection. |

## Sources

- [MicroPython uasyncio Docs](https://docs.micropython.org/en/latest/library/uasyncio.html) — Verified library status
- [InfluxData Documentation](https://docs.influxdata.com/influxdb/v2/) — Verified v2 is current stable OSS
- [Peter Hinch's mqtt_as](https://github.com/peterhinch/micropython-mqtt) — Community standard for robust MQTT
- [Mosquitto 2.0 Docs](https://mosquitto.org/documentation/) — Verified config requirements

---
*Stack research for: IoT Temperature Monitor*
*Researched: Tue Feb 17 2026*
