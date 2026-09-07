const rp2xxx = @import("microzig").hal;
const time = rp2xxx.time;
const board = @import("../platform/rp2040/board/pico_wh.zig");
const oled = @import("../platform/rp2040/drivers/oled.zig");
const display_content = @import("../domain/display_content.zig");
const usb_cdc = @import("../platform/rp2040/transport/usb_cdc.zig");
const Ticker = @import("../support/ticker.zig").Ticker;
const Readings = @import("./readings.zig").Readings;

const Self = @This();

const REFRESH_INTERVAL_US: u64 = 500_000;

readings: *const Readings,
ticker: Ticker,

pub fn init(pins: board.Pins, readings: *const Readings) !Self {
    try oled.init(pins.oled_sda, pins.oled_scl);
    oled.clear();
    oled.textRow(2, &display_content.SPLASH_TOP);
    oled.textRow(4, &display_content.SPLASH_VER);
    try oled.flush();
    return .{
        .readings = readings,
        .ticker = .{ .interval_us = REFRESH_INTERVAL_US },
    };
}

pub fn poll(self: *Self) void {
    const now = time.get_time_since_boot().to_us();
    if (!self.ticker.ready(now)) return;

    var temp_row: [16]u8 = undefined;
    _ = display_content.tempRow(&temp_row, self.readings.current_temp);
    oled.textRow(0, &temp_row);

    var dist_row: [16]u8 = undefined;
    _ = display_content.distanceRow(&dist_row, self.readings.distance_cm);
    oled.textRow(4, &dist_row);

    oled.flush() catch |err| {
        usb_cdc.write("display flush failed: {s}\r\n", .{@errorName(err)});
    };
}
