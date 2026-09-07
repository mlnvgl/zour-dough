const rp2xxx = @import("microzig").hal;
const time = rp2xxx.time;
const Blink = @import("../../../domain/blink.zig");

var gpio: rp2xxx.drivers.GPIO_Device = undefined;

pub fn init(pin: anytype) void {
    gpio = rp2xxx.drivers.GPIO_Device.init(pin);
}

pub fn set(state: Blink.LedState) void {
    gpio.write(if (state == .on) .high else .low) catch {};
}

// Visual "flash succeeded" confirmation: blink fast a few times before the
// main loop's heartbeat takes over. Blocking sleep_ms is fine here since
// it's meant to run before usb_cdc.init(), so there's no USB poll to starve.
pub fn bootBlink() void {
    var boot = Blink.BootBlink.init(Blink.BOOT_BLINK_COUNT);
    while (!boot.done()) {
        set(boot.next());
        time.sleep_ms(Blink.BOOT_BLINK_INTERVAL_MS);
    }
}
