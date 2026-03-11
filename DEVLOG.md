# Pico Dev Loop — Lessons Learned

## Goal
Set up a Zig firmware project for the Raspberry Pi Pico with:
- USB CDC serial output
- Auto-reflash on `zig build`
- Live serial monitoring

---

## Serial Port Not Appearing on macOS

**Symptom:** `ls /dev/tty.*` showed nothing after flashing.

**Root cause:** Two separate issues:
1. The initial firmware (LED blink only) had no USB stack at all — no serial port is created without USB CDC.
2. `time.sleep_ms(1)` in the main loop blocked USB polling too aggressively during enumeration. The USB CDC stack needs to be polled very frequently, especially at startup.

**Solution:**
- Add USB CDC to the firmware (imports, `DeviceController`, polling in the main loop).
- Remove blocking sleeps from the main loop — use time-based checks instead:

```zig
const now = time.get_time_since_boot().to_us();
if (now - last_toggle >= 250_000) { ... }
```

**Note:** The serial port name on macOS reflects the `serial` string in the firmware:
```zig
.serial = "someserial",
// → /dev/tty.usbmodemsomeserial1
```

---

## Permission Denied When Copying .uf2 on macOS Sequoia

**Symptom:** `cp blinky.uf2 /Volumes/RPI-RP2/` failed with `Permission denied`.

**Root cause:** macOS Sequoia (Darwin 25) restricts Python/subprocess access to removable volumes via TCC (privacy controls).

**Solution:** Use `picotool load -f blinky.uf2` instead of `cp`. picotool has the necessary entitlements to write to the device directly without going through the volume mount.

```bash
brew install picotool
picotool load -f zig-out/firmware/blinky.uf2
```

---

## LED Freezing / Constant On When Serial Logger Connected

**Symptom:** LED stopped blinking (stayed on) whenever `serial-logger.py` was running.

**Root cause:** `cdc_write` had two blocking loops with no timeout:

```zig
// Loop 1: blocks if TX buffer full (nobody reading)
while (tx.len > 0) {
    tx = tx[serial.write(tx)..];
    usb_device.poll(&usb_controller);
}

// Loop 2: blocks until all data flushed to host
while (!serial.flush()) usb_device.poll(&usb_controller);
```

When no host was reading (or CDC wasn't fully enumerated yet), both loops would spin forever, freezing the main loop and the LED toggle.

**Solution:** Add a shared deadline to both loops so `cdc_write` gives up after 10ms:

```zig
fn cdc_write(serial: *USB_Serial, comptime fmt: []const u8, args: anytype) void {
    var tx = std.fmt.bufPrint(&usb_tx_buf, fmt, args) catch return;
    const deadline = time.get_time_since_boot().to_us() + 10_000;
    while (tx.len > 0) {
        tx = tx[serial.write(tx)..];
        usb_device.poll(&usb_controller);
        if (time.get_time_since_boot().to_us() >= deadline) return;
    }
    while (!serial.flush()) {
        usb_device.poll(&usb_controller);
        if (time.get_time_since_boot().to_us() >= deadline) break;
    }
}
```

**Tradeoff:** Occasional messages get dropped if the host isn't reading fast enough. Acceptable for a debug log.

---

## Serial Logger Slow to Start / Hanging on Startup

**Symptom:** Running `serial-logger.py` caused a long pause with no LED activity before things worked.

**Root cause:** The script always rebooted the Pico into bootloader mode on startup (`picotool reboot -f -u`), then waited for the RPI-RP2 volume, then flashed — even when the firmware was already running and didn't need reflashing.

**Solution:** Split into two scripts:

- **`flash.py`** — reboots to bootloader, flashes, reboots to firmware. Run manually when you want to flash.
- **`serial-logger.py`** — just opens the serial port and reads. Only reflashes when the `.uf2` file changes (i.e. after `zig build`).

```
# Flash once:
python flash.py

# Monitor (auto-reflashes on zig build):
python serial-logger.py
```

---

## Workflow Summary

```
zig build                  # compile firmware
python flash.py            # first-time flash (or after manual reboot)
python serial-logger.py    # monitor serial, auto-reflash on zig build
```

To erase the Pico:
```bash
picotool erase -f          # wipe flash
picotool reboot -f -u      # reboot into bootloader (empty/waiting)
```
