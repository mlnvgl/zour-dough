const usb_cdc = @import("./helpers/usb_cdc.zig");
const status_led = @import("./status_led.zig");
const board = @import("./board.zig");
const Fermenter = @import("./fermenter.zig");

// Interval for the fermenter's periodic work (LED heartbeat, temp/heater
// check, ultrasound read). fast: 100ms, slow: 500_000
const MAIN_LOOP_INTERVAL_US: u64 = 800_000;

pub fn main() !void {
    const pins = board.apply();
    try status_led.init();
    status_led.bootBlink();
    usb_cdc.init();

    var fermenter = try Fermenter.init(pins, MAIN_LOOP_INTERVAL_US);

    while (true) {
        usb_cdc.poll();
        fermenter.poll();
    }
}
