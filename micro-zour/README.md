# Blinky DHT22 Sensor Firmware

Firmware for RP2040 (Raspberry Pi Pico) that reads temperature and humidity from a DHT22 sensor.

## Hardware Setup

- **DHT22 Data pin** → GPIO22
- **DHT22 VCC** → 3.3V
- **DHT22 GND** → GND
- **Optional**: 10kΩ pull-up resistor from Data pin to VCC
- **LED** → GPIO25 (shows sensor status via blinking pattern)

## LED Blinking Pattern

The LED on GPIO25 indicates the sensor status:

### Rapid Blink (Success)
- **Pattern**: 100ms ON, 100ms OFF, then 1.5 seconds pause
- **Meaning**: DHT22 sensor successfully read temperature and humidity values
- **Cycle**: Repeats every ~2 seconds

### Slow Pause (Error)
- **Pattern**: 500ms pause, then 1.5 seconds pause
- **Meaning**: DHT22 sensor failed to read data (timeout, bad checksum, or no response)
- **Cycle**: Repeats every ~2 seconds

## Building & Flashing

```bash
# Build the firmware
zig build

# Put Pico into bootloader mode:
# - Hold BOOTSEL button
# - Plug into laptop (or press RESET if already plugged in)
# - Release BOOTSEL
# - Pico appears as RPI-RP2 mass storage device

# Copy firmware to Pico
cp zig-out/firmware/blinky.uf2 /Volumes/RPI-RP2/
```

The Pico auto-flashes and reboots—firmware is now running!

## Sensor Status

- **Rapid blink** = ✅ Temperature and humidity readings are being captured
- **Slow pause** = ❌ Sensor communication failed

## Future Enhancements

- Add UART logging (requires USB-to-UART adapter)
- Store readings in memory
- Transmit data via WiFi (RP2350 with WiFi support)
