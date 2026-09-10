const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const ssd1306 = microzig.drivers.display.ssd1306;

const font8x8 = @import("font8x8");

const I2C_ADDR: u7 = 0x3C;

const Display = ssd1306.SSD1306_Generic(.{
    .mode = .i2c,
    .Datagram_Device = rp2xxx.drivers.I2C_Datagram_Device,
    .Digital_IO = @TypeOf(null),
});

var fb: ssd1306.Framebuffer = undefined;
var display: Display = undefined;

pub fn init(sda_pin: anytype, scl_pin: anytype) !void {
    inline for (.{ scl_pin, sda_pin }) |pin| {
        pin.set_slew_rate(.slow);
        pin.set_schmitt_trigger_enabled(true);
        pin.set_function(.i2c);
    }
    rp2xxx.i2c.instance.num(0).apply(.{
        .baud_rate = 400_000,
        .clock_config = rp2xxx.clock_config,
    });
    const dd = rp2xxx.drivers.I2C_Datagram_Device.init(rp2xxx.i2c.instance.num(0), @enumFromInt(I2C_ADDR), null);
    display = try ssd1306.init(.i2c, dd, null);
    fb = .init(.black);
}

pub fn textRow(page: u3, row: *const [16]u8) void {
    var gdram: [128]u8 = undefined;
    _ = font8x8.Fonts.draw(&gdram, row);
    @memcpy(fb.pixel_data[@as(usize, page) * 128 ..][0..128], &gdram);
}

pub fn invertRow(page: u3) void {
    for (fb.pixel_data[@as(usize, page) * 128 ..][0..128]) |*byte| byte.* = ~byte.*;
}

pub fn hline(y: u6) void {
    for (0..128) |x| fb.set_pixel(@intCast(x), y, .white);
}

pub fn clear() void {
    fb.clear(.black);
}

pub fn flush() !void {
    try display.write_full_display(fb.bit_stream());
}
