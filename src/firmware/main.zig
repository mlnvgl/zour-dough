const microzig = @import("microzig");
const usb_cdc = @import("./platform/rp2040/transport/usb_cdc.zig");
const rotary = @import("./platform/rp2040/drivers/rotary.zig");
const status_led = @import("./platform/rp2040/drivers/status_led.zig");
const board = @import("./platform/rp2040/board/pico.zig");
const Incubator = @import("./app/incubator.zig");
const Display = @import("./app/display.zig");
const Readings = @import("./domain/readings.zig").Readings;

pub const microzig_options = microzig.Options{
    .interrupts = .{ .IO_IRQ_BANK0 = .{ .c = rotary.onGpioIrq } },
};

pub fn main() !void {
    const pins = board.apply();

    init_peripherals(pins);

    var readings: Readings = .{};
    var incubator = try Incubator.init(pins, &readings);
    var display = try Display.init(pins, &readings);

    while (true) {
        usb_cdc.poll();
        incubator.poll();
        display.poll();
    }
}

pub fn init_peripherals(pins: board.Pins) void {
    status_led.init(pins.status_led);
    status_led.bootBlink();
    usb_cdc.init();
}
