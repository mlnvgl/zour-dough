from machine import Pin
import onewire
import ds18x20
import time


data_pin = Pin(22)
ow = onewire.OneWire(data_pin)
ds = ds18x20.DS18X20(ow)

roms = ds.scan()
if not roms:
	print("No DS18B20 sensors found on GPIO22")
else:
	print("Found {} sensor(s)".format(len(roms)))

while True:
	ds.convert_temp()
	time.sleep_ms(750)

	for rom in roms:
		temp_c = ds.read_temp(rom)
		print("DS18B20 {}: {:.2f} C".format(rom, temp_c))

	time.sleep(1)
