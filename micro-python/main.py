from machine import Pin
import onewire
import ds18x20
import uasyncio as asyncio
import ubinascii
import json
import network
from mqtt_as import MQTTClient, config
import mqtt_local # Import local config to update the global config

# Merge local config into mqtt_as config
# Note: mqtt_local.py should assign to config (from mqtt_as import config)
# effectively updating the dictionary in place.
# However, to be safe, we can manually update if needed, but since mqtt_local imports config
# and modifies it, it should be fine.

# Load application config
try:
    with open('config.json') as f:
        app_config = json.load(f)
    print("Loaded config.json:", app_config)
except Exception as e:
    print("Error loading config.json, using defaults:", e)
    app_config = {
        "temp_min": 27.0,
        "temp_max": 27.5,
        "check_interval": 10
    }

data_pin = Pin(22)
heater_pin = Pin(21, Pin.OUT)
heater_pin.value(0)
led_pin = Pin("LED", Pin.OUT)

MAX_TEMP = app_config.get("temp_max", 27.5)  # Celsius - turn heater off
MIN_TEMP = app_config.get("temp_min", 27.0)  # Celsius - turn heater on
CHECK_INTERVAL = app_config.get("check_interval", 10)  # Seconds between temperature checks

ow = onewire.OneWire(data_pin)
ds = ds18x20.DS18X20(ow)

roms = ds.scan()
if not roms:
    print("No DS18B20 sensors found on GPIO22")
else:
    print("Found {} sensor(s)".format(len(roms)))


def wifi_status_text(wlan):
    status_map = {
        getattr(network, "STAT_IDLE", 0): "IDLE",
        getattr(network, "STAT_CONNECTING", 1): "CONNECTING",
        2: "CONNECTING_NO_IP",
        getattr(network, "STAT_WRONG_PASSWORD", -3): "WRONG_PASSWORD",
        getattr(network, "STAT_NO_AP_FOUND", -2): "NO_AP_FOUND",
        getattr(network, "STAT_CONNECT_FAIL", -1): "CONNECT_FAIL",
        getattr(network, "STAT_GOT_IP", 3): "GOT_IP",
    }
    code = wlan.status()
    return "{} ({})".format(status_map.get(code, "UNKNOWN"), code)


def set_wifi_country_from_config():
    wifi_country = config.get('wifi_country')
    if not wifi_country:
        return
    try:
        import rp2
        rp2.country(wifi_country)
        print("Wi-Fi country set to '{}'".format(wifi_country))
    except Exception as e:
        print("Could not set Wi-Fi country '{}': {}".format(wifi_country, e))


def print_visible_ssids(wlan):
    try:
        networks = wlan.scan()
    except Exception as e:
        print("Wi-Fi scan failed: {}".format(e))
        return

    ssids = []
    for net in networks:
        raw_ssid = net[0]
        if isinstance(raw_ssid, bytes):
            ssid = raw_ssid.decode('utf-8', 'ignore')
        else:
            ssid = str(raw_ssid)
        if ssid and ssid not in ssids:
            ssids.append(ssid)

    if not ssids:
        print("Visible SSIDs: none")
        return

    max_show = 10
    print("Visible SSIDs ({}): {}".format(len(ssids), ", ".join(ssids[:max_show])))
    if len(ssids) > max_show:
        print("... and {} more".format(len(ssids) - max_show))


async def connect_with_retry(client):
    set_wifi_country_from_config()
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    wlan.config(pm=0xa11140)
    print("Power save disabled")

    attempt = 1
    while True:
        try:
            print("Connect attempt {} to SSID '{}' and MQTT {}:{}".format(attempt, config['ssid'], config['server'], config['port']))
            await client.connect()
            if wlan.isconnected():
                print("Wi-Fi connected: {}".format(wlan.ifconfig()))
            print("MQTT connected")
            return
        except OSError as e:
            print("Connection attempt {} failed: {}".format(attempt, e))
            status = wlan.status()
            print("Wi-Fi status: {}".format(wifi_status_text(wlan)))
            if status == getattr(network, "STAT_NO_AP_FOUND", -2) and (attempt == 1 or attempt % 3 == 0):
                print_visible_ssids(wlan)
            if wlan.isconnected():
                print("Wi-Fi still connected: {}".format(wlan.ifconfig()))
            else:
                try:
                    wlan.disconnect()
                except Exception:
                    pass
            attempt += 1
            await asyncio.sleep(5)

async def measure_and_publish(client):
    while True:
        led_pin.value(1)
        try:
            ds.convert_temp()
            await asyncio.sleep_ms(750) # Wait for conversion

            for rom in roms:
                rom_id = ubinascii.hexlify(rom).decode()
                temp_c = ds.read_temp(rom)
                print("DS18B20 {}: {:.2f} C".format(rom_id, temp_c))
                
                # Heater Logic
                heater_state = heater_pin.value()
                if temp_c >= MAX_TEMP:
                    heater_pin.value(0)  # Heater OFF
                    heater_state = 0
                    print("Heater OFF")
                elif temp_c < MIN_TEMP:
                    heater_pin.value(1)  # Heater ON
                    heater_state = 1
                    print("Heater ON")
                elif MIN_TEMP < temp_c < MAX_TEMP:
                    print("Temperature within range, no change to heater state")

                # MQTT Publish
                if client.isconnected():
                    payload = {
                        "sensor_id": rom_id,
                        "temperature": temp_c,
                        "heater": heater_state
                    }
                    topic = "sensors/ds18b20/{}".format(rom_id)
                    print("Publishing to {}: {}".format(topic, payload))
                    await client.publish(topic, json.dumps(payload), qos=1)
                else:
                    print("MQTT not connected, skipping publish")
            
            print("---")
        except Exception as e:
            print("Error: {}".format(e))
            
        led_pin.value(0)
        await asyncio.sleep(CHECK_INTERVAL)

async def main(client):
    await connect_with_retry(client)
    
    # Create the measurement task
    asyncio.create_task(measure_and_publish(client))
    
    # Keep the main loop running
    while True:
        await asyncio.sleep(1)

# Initialize MQTT Client
config['queue_len'] = 1 # Use event interface if needed, or just standard
MQTTClient.DEBUG = True  # Optional: print diagnostic messages
client = MQTTClient(config)

try:
    asyncio.run(main(client))
finally:
    client.close()  # Prevent LmacRxBlk:1 errors
