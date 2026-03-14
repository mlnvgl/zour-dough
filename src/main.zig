const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const usb_cdc = @import("./helpers/usb_cdc.zig");

const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO25 = .{ .name = "led", .direction = .out },
};

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
    if (now - last_toggle >= 250_000) {
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
