const microzig = @import("microzig");
const rp2xxx = @import("microzig").hal;
const time = rp2xxx.time;

const usb_cdc = @import("platform/rp2040/transport/usb_cdc.zig");
const rotary = @import("platform/rp2040/drivers/rotary.zig");
const status_led = @import("platform/rp2040/drivers/status_led.zig");
const oled = @import("platform/rp2040/drivers/oled.zig");
const board = @import("platform/rp2040/board/pico.zig");

const Incubator = @import("app/incubator.zig");
const Readings = @import("domain/readings.zig").Readings;
const Screen = @import("domain/ui/screen.zig").Screen;
const text = @import("domain/ui/text.zig");
const drawings = @import("domain/ui/drawings.zig");

pub const microzig_options = microzig.Options{
    .interrupts = .{ .IO_IRQ_BANK0 = .{ .c = rotary.onGpioIrq } },
};

pub fn main() !void {
    const pins = board.apply();

    init_peripherals(pins);

    var readings: Readings = .{};
    var incubator = try Incubator.init(pins, &readings);

    var screen = Screen.init(
        try oled.Oled.init(pins.oled_sda, pins.oled_scl),
        &readings,
    );

    try display_start_screen(&screen);

    while (true) {
        usb_cdc.poll();
        incubator.poll();
        screen.poll();
    }
}

pub fn init_peripherals(pins: board.Pins) void {
    status_led.init(pins.status_led);
    status_led.bootBlink();
    usb_cdc.init();
}

fn display_start_screen(screen: *Screen) !void {
    screen.draw_bitmap(
        0,
        0,
        drawings.ZIGGY_WIDTH,
        drawings.ZIGGY_HEIGHT,
        &drawings.ZIGGY,
    );
    try screen.flush();
    time.sleep_ms(2000);
    screen.clear();

    screen.text_row(2, &text.SPLASH_TOP);
    screen.text_row(4, &text.SPLASH_VER);
    try screen.flush();
    time.sleep_ms(2000);
    screen.clear();
}
