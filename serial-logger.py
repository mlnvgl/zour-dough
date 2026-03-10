import serial
import shutil
import time
import os
from pathlib import Path

def wait_for_drive(boot_drive):
    while not boot_drive.exists():
        time.sleep(0.1)

def wait_for_serial(serial_port):
    while not Path(serial_port).exists():
        time.sleep(0.1)

def flash(uf2_path, boot_drive):
    shutil.copy(uf2_path, boot_drive)
    print("Flashed!")

def reboot_to_bootloader(serial_port):
    try:
        ser = serial.Serial(serial_port, 115200, timeout=1)
        ser.write(b"__REBOOT_BOOTLOADER__\n")
        ser.close()
    except serial.SerialException:
        pass

def main():
    uf2_path = Path("./zig-out/firmware/blinky.uf2")
    serial_port = "/dev/ttyACM0"
    boot_drive = Path("/Volumes/RPI-RP2")

    # Initial flash
    reboot_to_bootloader(serial_port)
    wait_for_drive(boot_drive)
    flash(uf2_path, boot_drive)
    time.sleep(2)
    wait_for_serial(serial_port)

    last_modified = os.path.getmtime(uf2_path)
    ser = serial.Serial(serial_port, 115200, timeout=0.1)
    print("Watching for changes... (Ctrl+C to quit)\n")

    while True:
        # Check for new firmware
        try:
            current_modified = os.path.getmtime(uf2_path)
            if current_modified != last_modified:
                last_modified = current_modified
                print("\n--- Firmware changed, reflashing... ---")
                ser.close()
                reboot_to_bootloader(serial_port)
                wait_for_drive(boot_drive)
                flash(uf2_path, boot_drive)
                time.sleep(2)
                wait_for_serial(serial_port)
                ser = serial.Serial(serial_port, 115200, timeout=0.1)
                print("Reconnected.\n")
        except FileNotFoundError:
            pass

        # Read serial output
        line = ser.readline().decode(errors="replace")
        if line:
            print(line, end="")

if __name__ == "__main__":
    main()