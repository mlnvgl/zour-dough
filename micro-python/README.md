# Zour-Dough in MicroPython

This is a project about sour dough.

The purpose of this project is to build a system that keeps sour dough at a temperature of 28 degree celsius to build the perfect environment for the grow of the lactic acid bacteria. 

## Step 1: Install MicroPython on Your RP2350

If you haven't already:

1. Download the MicroPython UF2 file for RP2350 from [micropython.org](https://micropython.org). It is stored here under firmware folder
2. Hold the BOOTSEL button on your RP2350 while plugging it into your computer
3. It will appear as a USB drive - drag the UF2 file onto it
4. It will reboot with MicroPython installed

## Step 3: Configure Project

### Backend Secrets
1. Copy the example environment file:
   ```bash
   cp backend/.env.example backend/.env
   ```
2. Update `backend/.env` with your secure credentials.

### Firmware Secrets
1. Copy the example configuration file:
   ```bash
   cp mqtt_local.py.example mqtt_local.py
   ```
2. Open `mqtt_local.py` and enter your WiFi and MQTT broker details:
   - `ssid`: Your WiFi Network Name
   - `wifi_pw`: Your WiFi Password
   - `server`: IP Address of your computer running the MQTT broker (e.g. `192.168.1.50`)

**Note:** Both `mqtt_local.py` and `backend/.env` are ignored by git to keep your passwords safe.

## Step 4: Install Thonny IDE

Download and install [Thonny](https://thonny.org) - it's the easiest IDE for MicroPython beginners. It lets you write code and see the console output.


# Hardware

- **Controller:** Raspberry Pi Pico 2 W (RP2350)
- **Sensor:** DS18B20 Temperature Sensor
