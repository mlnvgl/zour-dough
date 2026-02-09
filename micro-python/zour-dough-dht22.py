from machine import Pin
import dht
import time

# Create DHT22 sensor object on GPIO 22
sensor = dht.DHT22(Pin(22))

# MOSFET on GPIO 12
heater = Pin(12, Pin.OUT)

# Temperature thresholds (adjust as needed!)
MAX_TEMP = 25  # Celsius - turn heater off
MIN_TEMP = 23.9  # Celsius - turn heater on
CHECK_INTERVAL = 2  # Seconds between temperature checks

while True:
    try:
        # Trigger measurement
        sensor.measure()
        
        # Read values
        temperature = sensor.temperature()
        humidity = sensor.humidity()
        
        # Print to console
        print(f"Temperature: {temperature}°C")
        print(f"Humidity: {humidity}%")
        
        # Temperature control
        if temperature >= MAX_TEMP:
            heater.value(0)  # Heater OFF
            print("Heater OFF")
        elif temperature <= MIN_TEMP:
            heater.value(1)  # Heater ON
            print("Heater ON")
        
        print("---")
        
    except OSError as e:
        print("Failed to read sensor:", e)
    
    # Check every CHECK_INTERVAL seconds
    time.sleep(CHECK_INTERVAL)