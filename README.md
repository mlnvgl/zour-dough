# Serial Logger

A serial monitor and auto-flasher for Raspberry Pi Pico development. It watches your compiled `.uf2` firmware for changes, automatically flashes it to the Pico, and streams serial output — creating a seamless develop-build-flash-monitor loop.

## How It Works

1. Reboots the Pico into bootloader mode over serial
2. Copies the `.uf2` firmware onto the Pico's USB mass-storage drive
3. Opens a serial connection and prints all output from the microcontroller
4. Watches the `.uf2` file for changes — when it detects a rebuild, it re-flashes and reconnects automatically

## Configuration

Edit the constants at the top of `main()` in `main.py` to match your setup:

| Variable       | Default                         | Description                              |
| -------------- | ------------------------------- | ---------------------------------------- |
| `uf2_path`     | `./zig-out/firmware.uf2`       | Path to the compiled firmware file       |
| `serial_port`  | `/dev/ttyACM0`                  | Serial port the Pico is connected to     |
| `boot_drive`   | `/media/you/RPI-RP2`           | Mount point of the Pico in bootloader mode |

## Requirements

- Python 3
- [pyserial](https://pypi.org/project/pyserial/)

```sh
pip install pyserial
```

## Usage

```sh
python main.py
```

The script will flash the firmware, then print serial output. Rebuild your firmware in another terminal and the script will detect the change, re-flash, and resume logging. Press `Ctrl+C` to quit.

## Notes

- The Pico firmware must handle the `__REBOOT_BOOTLOADER__` serial command to enter bootloader mode.
- On macOS, the serial port is typically `/dev/cu.usbmodemXXXX` and the boot drive is `/Volumes/RPI-RP2`.
