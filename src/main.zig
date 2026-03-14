const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const usb_cdc = @import("./helpers/usb_cdc.zig");

const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO25 = .{ .name = "led", .direction = .out },
};

pub fn main() !void {
    const pins = pin_config.apply();
    usb_cdc.init();

    var last_toggle: u64 = 0;
    var blink_count: u32 = 0;

    while (true) {
        usb_cdc.poll();

        const now = time.get_time_since_boot().to_us();
        if (now - last_toggle >= 250_000) {
            last_toggle = now;
            blink_count += 1;
            pins.led.toggle();
            usb_cdc.write("test blink blink blink {}\r\n", .{blink_count});
        }
    }
}
