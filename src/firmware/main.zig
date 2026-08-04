const usb_cdc = @import("./platform/rp2040/transport/usb_cdc.zig");
const status_led = @import("./platform/rp2040/drivers/status_led.zig");
const board = @import("./platform/rp2040/board/pico_wh.zig");
const Incubator = @import("./app/incubator.zig");

// Interval for the fermenter's periodic work (LED heartbeat, temp/heater
// check, ultrasound read). fast: 100ms, slow: 500_000
const MAIN_LOOP_INTERVAL_US: u64 = 800_000;

pub fn main() !void {
    const pins = board.apply();

    try init_peripherals();

    var incubator = try Incubator.init(pins, MAIN_LOOP_INTERVAL_US);

    while (true) {
        usb_cdc.poll();
        incubator.poll();
    }
}

pub fn init_peripherals() !void {
    try status_led.init();
    status_led.bootBlink();
    usb_cdc.init();
}
