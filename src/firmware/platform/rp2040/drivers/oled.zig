const std = @import("std");
const microzig = @import("microzig");

pub const HEIGHT = 64;
pub const WIDTH = 128;

const rp2xxx = microzig.hal;
const ssd1306 = microzig.drivers.display.ssd1306;

const I2C_ADDR: u7 = 0x3C;

const Display = ssd1306.SSD1306_Generic(.{
    .mode = .i2c,
    .Datagram_Device = rp2xxx.drivers.I2C_Datagram_Device,
    .Digital_IO = @TypeOf(null),
});

pub const Oled = struct {
    fb: ssd1306.Framebuffer,
    display: Display,

    pub fn init(sda_pin: anytype, scl_pin: anytype) !Oled {
        std.log.info("SSD1306: configuring pins", .{});

        inline for (.{ scl_pin, sda_pin }) |pin| {
            pin.set_slew_rate(.slow);
            pin.set_schmitt_trigger_enabled(true);
            pin.set_function(.i2c);
        }

        std.log.info("SSD1306: pins configured", .{});

        const i2c = rp2xxx.i2c.instance.num(0);

        std.log.info("SSD1306: configuring I2C0", .{});

        i2c.apply(.{
            .baud_rate = 400_000,
            .clock_config = rp2xxx.clock_config,
        });

        std.log.info("SSD1306: I2C0 configured", .{});

        const dd = rp2xxx.drivers.I2C_Datagram_Device.init(i2c, @enumFromInt(I2C_ADDR), null);

        std.log.info("SSD1306: datagram device created", .{});
        std.log.info("SSD1306: calling driver init", .{});

        return .{
            .display = try ssd1306.init(.i2c, dd, null),
            .fb = .init(.black),
        };
    }

    pub fn set_pixel(self: *Oled, x: u7, y: u6) void {
        self.fb.set_pixel(x, y, .white);
    }

    pub fn unset_pixel(self: *Oled, x: u7, y: u6) void {
        self.fb.set_pixel(x, y, .black);
    }

    pub fn clear(self: *Oled) void {
        self.fb.clear(.black);
    }

    pub fn flush(self: *Oled) !void {
        try self.display.write_full_display(self.fb.bit_stream());
    }
};
