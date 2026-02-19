# Feature Landscape

**Domain:** IoT Temperature Monitor (MicroPython + DS18B20)
**Researched:** Tue Feb 17 2026

## Table Stakes

Features users expect. Missing = product feels incomplete or broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **WiFi Auto-Reconnect** | IoT devices must recover from router reboots without manual intervention. | Medium | Requires a state machine or robust loop to check `sta_if.isconnected()` and reconnect. |
| **Reliable Sensor Reading** | The core purpose. Must handle the 750ms conversion delay and verify CRC. | Low | Use standard `ds18x20` and `onewire` modules. Handle `85.0` (power-on reset) value filtering. |
| **MQTT Publishing** | Standard protocol for this stack. Needs to push JSON payloads to Mosquitto. | Low | Use `umqtt.simple`. Topic structure: `sensors/temp_monitor/temperature`. |
| **Watchdog Timer (WDT)** | Headless devices must self-recover from freezes. | Low | Use `machine.WDT`. Feed it in the main loop. |
| **Error Reporting** | If the sensor is unplugged, the system should know (e.g., publish `null` or error status). | Low | Don't just fail silently or crash. |

## Differentiators

Features that set a "professional" hobby project apart from a "tutorial" script.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Captive Portal Config** | Allows setting WiFi/MQTT creds without editing code/re-flashing. | High | Boots into AP mode if WiFi fails. User connects to "TempMonitor-Setup" to configure. |
| **Asynchronous Loop** | Uses `uasyncio` to remain responsive to network events while waiting for sensor conversion. | Medium | "Non-blocking" architecture. Allows handling OTA or status checks during the 750ms wait. |
| **Deep Sleep Power Saving** | Enables battery operation (months vs hours). | Medium | Essential if not USB powered. Connect `RST` to `D0` (ESP8266) or simple API (ESP32). |
| **Offline Buffering** | No data loss during WiFi outages. Queues readings in RAM/Flash. | High | Publish queue when connection restores. Adds timestamping complexity (needs NTP). |
| **Over-the-Air (OTA) Updates** | Update firmware without plugging in USB. | High | Pulls `main.py` from a server or accepts via MQTT/HTTP. |
| **Device Health Telemetry** | Reports WiFi RSSI, free RAM, and uptime alongside temperature. | Low | Helps diagnose "why did it stop working?" (usually weak WiFi). |

## Anti-Features

Features to explicitly NOT build. Common mistakes in this domain.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Hardcoded Credentials** | Security risk; requires code change to move device. | Use a `config.json` file or Captive Portal. |
| **Blocking `time.sleep()`** | Freezes the CPU. Can cause network timeouts or WDT resets. | Use `uasyncio.sleep()` or non-blocking timer checks. |
| **Local Display (OLED)** | Increases power/cost/complexity. This is a headless logger. | Visualize data in Grafana (part of the stack). |
| **History on Device** | ESPs have limited RAM/Flash. | Push to InfluxDB; let the server handle history. |
| **High Frequency Logging (<10s)** | DS18B20 self-heating can skew readings. | Sample every 60s or 5m. It's ambient temp, not a reaction vessel. |

## Feature Dependencies

```
WiFi Auto-Reconnect
       ↓
NTP Time Sync (Required for correct timestamps if buffering)
       ↓
Offline Buffering (Depends on Time Sync)

WiFi Auto-Reconnect
       ↓
MQTT Publishing
       ↓
Device Health Telemetry (Piggybacks on MQTT)
```

## MVP Recommendation

For MVP, prioritize reliability over features.

1.  **WiFi Auto-Reconnect** (Robustness first)
2.  **Reliable Sensor Reading** (Core function)
3.  **MQTT Publishing** (Data egress)
4.  **Config via `config.json`** (Avoid hardcoding, simpler than Portal)

Defer to post-MVP:
-   **Captive Portal** (High effort)
-   **Offline Buffering** (Complexity)
-   **OTA Updates** (Complexity)

## Sources

-   [MicroPython Network Basics](https://docs.micropython.org/en/latest/esp8266/tutorial/network_basics.html)
-   [MicroPython DS18B20 Tutorial](https://docs.micropython.org/en/latest/esp8266/tutorial/onewire.html)
