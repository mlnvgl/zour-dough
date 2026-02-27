from machine import Pin
import onewire
import ds18x20
import uasyncio as asyncio
import ubinascii
import json
from mqtt_as import MQTTClient, config
import mqtt_local # Import local config to update the global config

# Merge local config into mqtt_as config
# Note: mqtt_local.py should assign to config (from mqtt_as import config)
# effectively updating the dictionary in place.
# However, to be safe, we can manually update if needed, but since mqtt_local imports config
# and modifies it, it should be fine.

data_pin = Pin(22)
heater_pin = Pin(21, Pin.OUT)
heater_pin.value(0)
led_pin = Pin("LED", Pin.OUT)

MAX_TEMP = 27.5  # Celsius - turn heater off
MIN_TEMP = 27  # Celsius - turn heater on
CHECK_INTERVAL = 3  # Seconds between temperature checks

ow = onewire.OneWire(data_pin)
ds = ds18x20.DS18X20(ow)

roms = ds.scan()
if not roms:
    print("No DS18B20 sensors found on GPIO22")
else:
    print("Found {} sensor(s)".format(len(roms)))

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
                    topic = "zour-dough/ds18b20/{}".format(rom_id)
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
    try:
        await client.connect()
    except OSError:
        print('Connection failed')
        # mqtt_as handles reconnection, so we can continue or return
        # But usually we want the loop to run
    
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
