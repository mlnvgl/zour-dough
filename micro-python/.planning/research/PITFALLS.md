# Domain Pitfalls

**Domain:** IoT Temperature Monitor (MicroPython + DS18B20 + Docker Stack)
**Researched:** 2026-02-17

## Critical Pitfalls

Mistakes that cause rewrites, hardware replacement, or total data loss.

### Pitfall 1: The "Counterfeit DS18B20" Trap
**What goes wrong:** The market is flooded with fake DS18B20 sensors (clones). They often fail in "parasitic power" mode (2-wire), have high noise, incorrect temperature readings (offsets > 2°C), or stop working entirely after a few weeks.
**Why it happens:** Genuine Maxim/Analog Devices chips are significantly more expensive ($4-5) than the clones found on eBay/AliExpress ($1-2 for 5).
**Consequences:** Unreliable data, random disconnects, or persistent "85°C" error readings (power-on reset value).
**Prevention:** 
- **Avoid parasitic power mode** on cheap sensors; always run 3 wires (VCC, GND, DATA).
- Buy from authorized distributors (DigiKey, Mouser) for the "gold standard" reference.
- If using cheap probes, test them immediately using a known genuine sensor as a reference.
**Detection:** 
- Check ROM code: Genuine often follow `28-xx-xx-xx-xx-00-00-xx` pattern.
- Timing test: Fakes often have very different conversion times (e.g., <500ms or >750ms) compared to the genuine ~600-750ms.
**Phase to Address:** Phase 1 (Hardware/Sensor validation)

### Pitfall 2: Blocking MQTT & WiFi Loops
**What goes wrong:** The MicroPython script uses a simple `while True` loop with blocking calls like `client.connect()` or `time.sleep()`. When WiFi drops or the broker restarts, the script throws an unhandled exception and crashes, or hangs indefinitely.
**Why it happens:** `umqtt.simple` is blocking. `umqtt.robust` helps but can still block execution flow if not configured with non-blocking sockets or `asyncio`.
**Consequences:** The device goes offline and never comes back without a manual power cycle.
**Prevention:**
- Use `uasyncio` for non-blocking delays and tasks (`await asyncio.sleep()`).
- Implement a robust "Check WiFi -> Check MQTT -> Reconnect if needed" logic in the main loop.
- Enable `machine.WDT` (Watchdog Timer) to auto-reset the device if the loop hangs for >60 seconds.
**Phase to Address:** Phase 2 (Firmware Prototype)

### Pitfall 3: Flash Wearout (Filesystem Abuse)
**What goes wrong:** Logging data locally to the ESP8266/ESP32 filesystem (e.g., appending to `log.txt`) before sending, or saving state too frequently.
**Why it happens:** Flash memory has limited write cycles (typically 10k-100k). Writing every minute destroys the sector quickly.
**Consequences:** Device filesystem becomes read-only or corrupt; boot loops.
**Prevention:**
- **Do not log sensor data to local flash.** Send directly to MQTT.
- If buffering is needed (for network outages), keep it in RAM (Python list) and discard if RAM fills up (circular buffer).
**Phase to Address:** Phase 2 (Firmware Prototype)

## Moderate Pitfalls

Mistakes that cause delays or technical debt.

### Pitfall 1: The 4.7kΩ Pull-Up Resistor Myth
**What goes wrong:** Users assume the internal pull-up of the ESP8266/ESP32 is sufficient, or they use a 4.7kΩ resistor for *long* cable runs.
**Prevention:** 
- External 4.7kΩ resistor is mandatory (internal pull-ups are too weak, ~30-50kΩ).
- For long cables (>5m), lower the resistance to ~2.2kΩ or use a 5V supply for the sensor (with 3.3V pull-up on Data line to protect ESP GPIO).
**Phase to Address:** Phase 1 (Hardware Assembly)

### Pitfall 2: InfluxDB Cardinality Explosion
**What goes wrong:** Using a tag for values that change (e.g., `tag(temperature=25.4)` instead of `field(temperature=25.4)`).
**Consequences:** InfluxDB memory usage spikes, queries become slow, database crashes.
**Prevention:** 
- Tags are for metadata (SensorID, Location).
- Fields are for measured values (Temperature, Humidity).
**Phase to Address:** Phase 3 (Backend Setup)

### Pitfall 3: Time Synchronization Drift
**What goes wrong:** The ESP logs data with its internal boot time (millis) or a drifting clock.
**Consequences:** Data in Grafana appears with wrong timestamps (1970 epoch) or drifts by minutes/hours over weeks.
**Prevention:** 
- Use `ntptime.settime()` on boot and periodically (e.g., every 6 hours).
- Or better: Let the backend (Telegraf/Node-RED/Python script) assign the timestamp upon receipt if precise millisecond latency isn't critical.
**Phase to Address:** Phase 2 (Firmware Prototype)

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| **Hardware** | Using GPIO0/GPIO2/GPIO15 for sensors | These are strapping pins on ESP8266/ESP32. Using them can prevent boot. Use "safe" GPIOs (e.g., D1, D2, D5, D6 on Wemos D1 Mini). |
| **Firmware** | Memory Fragmentation | Periodic `gc.collect()` in the main loop. Avoid allocating large strings or buffers repeatedly. |
| **Backend** | Docker Volume Persistence | Forgetting to mount a volume for InfluxDB/Grafana data. `docker-compose down` wipes all history. |
| **Sensor** | Reading `85.0` (power-on reset value) | Discard the first reading from DS18B20 or wait 1s after power-up. |

## Sources

- **Counterfeit DS18B20:** https://github.com/cpetrich/counterfeit_DS18B20 (Detailed analysis of fake sensors)
- **MicroPython OneWire:** https://docs.micropython.org/en/latest/esp8266/tutorial/onewire.html
- **InfluxDB Schema Design:** Official InfluxData documentation regarding Cardinality.
- **Asyncio Tutorial:** https://github.com/peterhinch/micropython-async (Essential for non-blocking loops)
