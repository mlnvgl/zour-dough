f the Pico is mounted as RPI-RP2 it's already in bootloader mode — there's no serial port in that state. The serial port only exists when the Pico is running firmware.

Check which situation you're in:


ls /Volumes/RPI-RP2
If that exists — skip the stty step entirely, just cp the UF2:


cp zig-out/firmware/blinky.uf2 /Volumes/RPI-RP2/
If it doesn't exist — the Pico is running firmware and the serial port should appear as /dev/tty.usbmodem*. Try:


ls /dev/tty.*
The stty 1200-baud touch is only needed to trigger the bootloader when the Pico is running. If it's already in bootloader mode, your script should detect that and skip straight to the cp.