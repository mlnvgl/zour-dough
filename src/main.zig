const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const usb_cdc = @import("./helpers/usb_cdc.zig");

const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO25 = .{ .name = "led", .direction = .out },
};

// Change this to select the blink phase
const BLINK_INTERVAL_US: u64 = 800_000; // fast: 100ms, slow: 500_000

const Pins = @TypeOf(pin_config.apply());
var pins: Pins = undefined;
var last_toggle: u64 = 0;
var blink_count: u32 = 0;

fn init() void {
    pins = pin_config.apply();
    usb_cdc.init();
}

fn tick() void {
    usb_cdc.poll();
    const now = time.get_time_since_boot().to_us();
    if (now - last_toggle >= BLINK_INTERVAL_US) {
        last_toggle = now;
        blink_count += 1;
        pins.led.toggle();
        usb_cdc.write("blink {}\r\n", .{blink_count});
    }
}

pub fn main() !void {
    init();
    while (true) tick();
}
