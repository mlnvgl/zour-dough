import serial
import subprocess
import time
import os
from pathlib import Path

SERIAL_PORT = "/dev/tty.usbmodemsomeserial1"
UF2_PATH = Path("./zig-out/firmware/blinky.uf2")

def wait_for_serial():
    while not Path(SERIAL_PORT).exists():
        time.sleep(0.1)

def reflash():
    print("\n--- Firmware changed, reflashing... ---")
    subprocess.run(["python", "flash.py"], check=True)
    wait_for_serial()

def main():
    wait_for_serial()
    last_modified = os.path.getmtime(UF2_PATH)
    ser = serial.Serial(SERIAL_PORT, 115200, timeout=0.1)
    print("Watching for changes... (Ctrl+C to quit)\n")

    while True:
        try:
            current_modified = os.path.getmtime(UF2_PATH)
            if current_modified != last_modified:
                last_modified = current_modified
                ser.close()
                reflash()
                ser = serial.Serial(SERIAL_PORT, 115200, timeout=0.1)
                print("Reconnected.\n")
        except FileNotFoundError:
            pass

        line = ser.readline().decode(errors="replace")
        if line:
            print(line, end="")

if __name__ == "__main__":
    main()
