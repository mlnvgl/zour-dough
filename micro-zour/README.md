# Blinky DHT22 Sensor Firmware

Firmware for RP2040 (Raspberry Pi Pico) that reads temperature and humidity from a DHT22 sensor.

## Hardware Setup

- **DHT22 Data pin** → GPIO22
- **DHT22 VCC** → 3.3V
- **DHT22 GND** → GND
- **Optional**: 10kΩ pull-up resistor from Data pin to VCC
- **LED** → GPIO25 (shows sensor status via blinking pattern)

## LED Blinking Pattern

The LED on GPIO25 clearly indicates the sensor status:

### Success - 3 Rapid Blinks
- **Pattern**: 3 quick flashes (150ms ON, 150ms OFF each), then 1 second pause
- **Meaning**: DHT22 sensor successfully read temperature and humidity
- **Cycle**: Repeats every ~2 seconds
- **Visual**: Easy to count—you'll see "blink, blink, blink"

### Error - 1 Long Slow Blink
- **Pattern**: 1 second ON, 1 second OFF
- **Meaning**: DHT22 sensor failed (timeout, bad checksum, or no response)
- **Cycle**: Repeats every 2 seconds
- **Visual**: Very obvious—one long slow pulse

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

- **3 quick blinks** = ✅ Sensor reading successful
- **1 long slow blink** = ❌ Sensor communication failed

## Future Enhancements

- Add UART logging (requires USB-to-UART adapter)
- Store readings in memory
- Transmit data via WiFi (RP2350 with WiFi support)
