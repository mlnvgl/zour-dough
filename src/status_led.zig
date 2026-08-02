const rp2xxx = @import("microzig").hal;
const cyw43 = rp2xxx.cyw43;
const time = rp2xxx.time;
const Blink = @import("./blink.zig");

// This board is a Pico WH: the onboard LED lives behind the CYW43439
// wireless chip (GPIO25 is the wireless SPI chip-select line instead), so
// it's driven via `cyw43.gpio.put` rather than a plain GPIO pin.
pub fn init() !void {
    try cyw43.init();
}

pub fn set(state: Blink.LedState) void {
    cyw43.gpio.put(.led, state == .on);
}

var heartbeat_state: Blink.LedState = .off;

// Flips the heartbeat LED. Caller decides *when* (loop cadence lives with
// the caller); this just owns the on/off state itself.
pub fn toggle() void {
    heartbeat_state = heartbeat_state.toggled();
    set(heartbeat_state);
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
