const rp2xxx = @import("microzig").hal;
const time = rp2xxx.time;
const board = @import("../platform/rp2040/board/pico.zig");
const oled = @import("../platform/rp2040/drivers/oled.zig");
const display_content = @import("../domain/display_content.zig");
const usb_cdc = @import("../platform/rp2040/transport/usb_cdc.zig");
const Ticker = @import("../support/timing.zig").Ticker;
const Readings = @import("../domain/readings.zig").Readings;

const Self = @This();

const REFRESH_INTERVAL_US: u64 = 500_000;
const SEPARATOR_Y: u6 = 47;
const STATUS_PAGE: u3 = 7;

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
    if (self.ticker.poll(now) == .waiting) return;

    var temp_row: [16]u8 = undefined;
    _ = display_content.tempRow(&temp_row, self.readings.freshTemp(now));
    oled.textRow(0, &temp_row);

    var target_row: [16]u8 = undefined;
    _ = display_content.targetRow(&target_row, self.readings.target_temp);
    oled.textRow(2, &target_row);

    var dist_row: [16]u8 = undefined;
    _ = display_content.distanceRow(&dist_row, self.readings.distance_cm);
    oled.textRow(4, &dist_row);

    const heating = self.readings.heat == .heating;

    var status_row: [16]u8 = undefined;
    _ = display_content.statusRow(&status_row, heating);
    oled.textRow(STATUS_PAGE, &status_row);
    if (heating) oled.invertRow(STATUS_PAGE);

    oled.hline(SEPARATOR_Y);

    oled.flush() catch |err| {
        usb_cdc.write("display flush failed: {s}\r\n", .{@errorName(err)});
    };
}
