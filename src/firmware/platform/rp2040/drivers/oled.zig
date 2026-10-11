const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const ssd1306 = microzig.drivers.display.ssd1306;

const font8x8 = @import("font8x8").Fonts;

const I2C_ADDR: u7 = 0x3C;

const Display = ssd1306.SSD1306_Generic(.{
    .mode = .i2c,
    .DatagramDevice = rp2xxx.drivers.I2C_DatagramDevice,
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
    const dd = rp2xxx.drivers.I2C_DatagramDevice.init(rp2xxx.i2c.instance.num(0), @fromBackingInt(@intCast(I2C_ADDR)), null);
    display = try ssd1306.init(.i2c, dd, null);
    fb = .init(.black);
}

pub fn textRow(page: u3, row: *const [16]u8) void {
    var gdram: [128]u8 = undefined;
    for (row, 0..) |char, index| {
        const bitmap = glyph(char);
        @memcpy(gdram[index * 8 ..][0..8], &bitmap);
    }
    @memcpy(fb.pixel_data[@as(usize, page) * 128 ..][0..128], &gdram);
}

// In Zig 17 the declaration reflection was removed. std.builtin.Type.Struct no longer provides .decls field.
fn glyph(char: u8) [8]u8 {
    return switch (char) {
        '0' => font8x8.Fonts.@"0",
        '1' => font8x8.Fonts.@"1",
        '2' => font8x8.Fonts.@"2",
        '3' => font8x8.Fonts.@"3",
        '4' => font8x8.Fonts.@"4",
        '5' => font8x8.Fonts.@"5",
        '6' => font8x8.Fonts.@"6",
        '7' => font8x8.Fonts.@"7",
        '8' => font8x8.Fonts.@"8",
        '9' => font8x8.Fonts.@"9",
        'A' => font8x8.Fonts.A,
        'B' => font8x8.Fonts.B,
        'C' => font8x8.Fonts.C,
        'D' => font8x8.Fonts.D,
        'E' => font8x8.Fonts.E,
        'F' => font8x8.Fonts.F,
        'G' => font8x8.Fonts.G,
        'H' => font8x8.Fonts.H,
        'I' => font8x8.Fonts.I,
        'J' => font8x8.Fonts.J,
        'K' => font8x8.Fonts.K,
        'L' => font8x8.Fonts.L,
        'M' => font8x8.Fonts.M,
        'N' => font8x8.Fonts.N,
        'O' => font8x8.Fonts.O,
        'P' => font8x8.Fonts.P,
        'Q' => font8x8.Fonts.Q,
        'R' => font8x8.Fonts.R,
        'S' => font8x8.Fonts.S,
        'T' => font8x8.Fonts.T,
        'U' => font8x8.Fonts.U,
        'V' => font8x8.Fonts.V,
        'W' => font8x8.Fonts.W,
        'X' => font8x8.Fonts.X,
        'Y' => font8x8.Fonts.Y,
        'Z' => font8x8.Fonts.Z,
        'a' => font8x8.Fonts.a,
        'b' => font8x8.Fonts.b,
        'c' => font8x8.Fonts.c,
        'd' => font8x8.Fonts.d,
        'e' => font8x8.Fonts.e,
        'f' => font8x8.Fonts.f,
        'g' => font8x8.Fonts.g,
        'h' => font8x8.Fonts.h,
        'i' => font8x8.Fonts.i,
        'j' => font8x8.Fonts.j,
        'k' => font8x8.Fonts.k,
        'l' => font8x8.Fonts.l,
        'm' => font8x8.Fonts.m,
        'n' => font8x8.Fonts.n,
        'o' => font8x8.Fonts.o,
        'p' => font8x8.Fonts.p,
        'q' => font8x8.Fonts.q,
        'r' => font8x8.Fonts.r,
        's' => font8x8.Fonts.s,
        't' => font8x8.Fonts.t,
        'u' => font8x8.Fonts.u,
        'v' => font8x8.Fonts.v,
        'w' => font8x8.Fonts.w,
        'x' => font8x8.Fonts.x,
        'y' => font8x8.Fonts.y,
        'z' => font8x8.Fonts.z,
        ' ' => font8x8.Fonts.@" ",
        '!' => font8x8.Fonts.@"!",
        '"' => font8x8.Fonts.@"\"",
        '#' => font8x8.Fonts.@"#",
        '$' => font8x8.Fonts.@"$",
        '%' => font8x8.Fonts.@"%",
        '&' => font8x8.Fonts.@"&",
        '@' => font8x8.Fonts.@"@",
        else => font8x8.Fonts.@" ",
    };
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
