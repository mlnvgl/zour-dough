from machine import Pin
import onewire
import ds18x20
import time
import ubinascii

data_pin = Pin(22)
heater_pin = Pin(21, Pin.OUT)
heater_pin.value(0)


MAX_TEMP = 25  # Celsius - turn heater off
MIN_TEMP = 23  # Celsius - turn heater on
CHECK_INTERVAL = 3  # Seconds between temperature checks

ow = onewire.OneWire(data_pin)
ds = ds18x20.DS18X20(ow)

roms = ds.scan()
if not roms:
	print("No DS18B20 sensors found on GPIO22")
else:
	print("Found {} sensor(s)".format(len(roms)))

while True:
	try:
		ds.convert_temp()
		time.sleep_ms(750)

		for rom in roms:
			temp_c = ds.read_temp(rom)
			print("DS18B20 {}: {:.2f} C".format(ubinascii.hexlify(rom).decode(), temp_c))
			if temp_c >= MAX_TEMP:
				heater_pin.value(0)  # Heater OFF
				print("Heater OFF")
			elif temp_c <= MIN_TEMP:
				heater_pin.value(1)  # Heater ON
				print("Heater ON")

			print("PerfectCurrent Temperature of {:.2f} C".format(temp_c))

		print("---")
	except Exception as e:
		print("Error: {}".format(e))
		
	time.sleep(CHECK_INTERVAL)