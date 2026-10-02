const std = @import("std");
const font8x8 = @import("font8x8");
const rp2xxx = @import("microzig").hal;
const time = rp2xxx.time;

const oled_mod = @import("../../platform/rp2040/drivers/oled.zig");
const Oled = oled_mod.Oled;

const usb_cdc = @import("../../platform/rp2040/transport/usb_cdc.zig");
const Ticker = @import("../../support/timing.zig").Ticker;
const Readings = @import("../readings.zig").Readings;
const text = @import("text.zig");

const REFRESH_INTERVAL_US: u64 = 500_000;
const SEPARATOR_Y: u6 = 47;
const STATUS_PAGE: u3 = 7;

pub const Screen = struct {
    oled: Oled,
    readings: *const Readings,
    ticker: Ticker,

    pub fn init(oled: Oled, readings: *const Readings) Screen {
        return .{
            .oled = oled,
            .readings = readings,
            .ticker = .{ .interval_us = REFRESH_INTERVAL_US },
        };
    }

    pub fn text_row(self: *Screen, page: u3, row: *const [16]u8) void {
        var gdram: [128]u8 = undefined;
        _ = font8x8.Fonts.draw(&gdram, row);
        @memcpy(self.oled.fb.pixel_data[@as(usize, page) * 128 ..][0..128], &gdram);
    }

    pub fn invert_row(self: *Screen, page: u3) void {
        for (self.oled.fb.pixel_data[@as(usize, page) * 128 ..][0..128]) |*byte| byte.* = ~byte.*;
    }

    pub fn hline(self: *Screen, y: u6) void {
        for (0..128) |x| self.oled.set_pixel(@intCast(x), y);
    }

    pub fn flush(self: *Screen) !void {
        try self.oled.flush();
    }

    pub fn draw_bitmap(
        self: *Screen,
        start_x: u7,
        start_y: u6,
        bm_width: usize,
        bm_height: usize,
        bitmap: []const u8,
    ) void {
        const bytes_per_row = (bm_width + 7) / 8;


        for (0..bm_height) |y| {
            for (0..bm_width) |x| {
                if (start_x + x >= oled_mod.WIDTH) continue;
                if (start_y + y >= oled_mod.HEIGHT) continue;

                const byte_index = y * bytes_per_row + (x >> 3);
                const bit_index = x & 7;
                const mask = @as(u8, 0x80) >> @truncate(bit_index);

                if (bitmap[byte_index] & mask != 0)
                    self.oled.set_pixel(
                        @as(u7, @intCast(start_x + x)),
                        @as(u6, @intCast(start_y + y)),
                    )
                else
                    self.oled.unset_pixel(
                        @as(u7, @intCast(start_x + x)),
                        @as(u6, @intCast(start_y + y)),
                    );
            }
        }
    }

    pub fn poll(self: *Screen) void {
        const now = time.get_time_since_boot().to_us();
        if (self.ticker.poll(now) == .waiting) return;

        var temp_row: [16]u8 = undefined;
        _ = text.temp_row(&temp_row, self.readings.freshTemp(now));
        self.text_row(0, &temp_row);

        var target_row: [16]u8 = undefined;
        _ = text.target_row(&target_row, self.readings.target_temp);
        self.text_row(2, &target_row);

        var dist_row: [16]u8 = undefined;
        _ = text.distance_row(&dist_row, self.readings.distance_cm);
        self.text_row(4, &dist_row);

        const heating = self.readings.heat == .heating;

        var status_row: [16]u8 = undefined;
        _ = text.status_row(&status_row, heating);
        self.text_row(STATUS_PAGE, &status_row);
        if (heating) self.invert_row(STATUS_PAGE);

        self.hline(SEPARATOR_Y);

        self.flush() catch |err| {
            usb_cdc.write("display flush failed: {s}\r\n", .{@errorName(err)});
        };
    }

    pub fn clear(self: *Screen) void {
        self.oled.clear();
    }
};
