import subprocess
import time
from pathlib import Path

SERIAL_PORT = "/dev/tty.usbmodemsomeserial1"
UF2_PATH = Path("./../../zig-out/firmware/blinky.uf2")

def main():
    print("Rebooting to bootloader...")
    subprocess.run(["picotool", "reboot", "-f", "-u"], check=False, capture_output=True)
    time.sleep(1)

    print(f"Flashing {UF2_PATH}...")
    result = subprocess.run(
        ["picotool", "load", "-f", "-x", str(UF2_PATH)],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"Flash failed: {result.stderr}")
        raise SystemExit(1)
    print("Done!")

if __name__ == "__main__":
    main()
