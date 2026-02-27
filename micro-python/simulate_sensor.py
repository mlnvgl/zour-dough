import paho.mqtt.client as mqtt
import json
import time
import random

broker = "localhost"
port = 1883
topic_base = "sensors/ds18b20/"
sensor_id = "SIMULATED_ID"

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connected to broker")
    else:
        print(f"Connection failed with code {rc}")

client = mqtt.Client()
client.on_connect = on_connect

try:
    client.connect(broker, port)
    client.loop_start()
    time.sleep(1)
    
    topic = f"{topic_base}{sensor_id}"
    temp = 25.0 + random.uniform(-0.5, 0.5)
    payload = {
        "sensor_id": sensor_id,
        "temperature": round(temp, 2),
        "heater": 0
    }
    
    print(f"Publishing to {topic}: {payload}")
    client.publish(topic, json.dumps(payload))
    time.sleep(1)
    
except Exception as e:
    print(f"Error: {e}")
finally:
    client.loop_stop()
    client.disconnect()
