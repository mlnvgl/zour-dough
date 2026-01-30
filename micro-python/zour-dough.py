from machine import Pin
import dht
import time

# Create DHT22 sensor object on GPIO 22
sensor = dht.DHT22(Pin(22))

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
        print("---")
        
    except OSError as e:
        print("Failed to read sensor:", e)
    
    # Wait 2 seconds before next reading
    time.sleep(2)