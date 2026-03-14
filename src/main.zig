const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const usb = microzig.core.usb;
const USB_Device = rp2xxx.usb.Polled(.{});
const USB_Serial = usb.drivers.CDC;

const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO25 = .{ .name = "led", .direction = .out },
};

var usb_device: USB_Device = undefined;

var usb_controller: usb.DeviceController(.{
    .bcd_usb = USB_Device.max_supported_bcd_usb,
    .device_triple = .unspecified,
    .vendor = USB_Device.default_vendor_id,
    .product = USB_Device.default_product_id,
    .bcd_device = .v1_00,
    .serial = "someserial",
    .max_supported_packet_size = USB_Device.max_supported_packet_size,
    .configurations = &.{.{
        .attributes = .{ .self_powered = false },
        .max_current_ma = 50,
        .Drivers = struct { serial: USB_Serial, reset: rp2xxx.usb.ResetDriver(null, 0) },
    }},
}, .{.{
    .serial = .{ .itf_notifi = "Board CDC", .itf_data = "Board CDC Data" },
    .reset = "",
}}) = .init;

var usb_tx_buf: [256]u8 = undefined;
var usb_rx_buf: [256]u8 = undefined;

fn cdc_write(serial: *USB_Serial, comptime fmt: []const u8, args: anytype) void {
    var tx = std.fmt.bufPrint(&usb_tx_buf, fmt, args) catch return;
    const deadline = time.get_time_since_boot().to_us() + 10_000;
    while (tx.len > 0) {
        tx = tx[serial.write(tx)..];
        usb_device.poll(&usb_controller);
        if (time.get_time_since_boot().to_us() >= deadline) return;
    }
    while (!serial.flush()) {
        usb_device.poll(&usb_controller);
        if (time.get_time_since_boot().to_us() >= deadline) break;
    }
}

fn cdc_read(serial: *USB_Serial) []const u8 {
    var len: usize = 0;
    while (true) {
        const n = serial.read(usb_rx_buf[len..]);
        len += n;
        if (n == 0) break;
    }
    return usb_rx_buf[0..len];
}

pub fn main() !void {
    const pins = pin_config.apply();
    usb_device = .init();

    var last_toggle: u64 = 0;
    var blink_count: u32 = 0;

    while (true) {
        usb_device.poll(&usb_controller);

        const now = time.get_time_since_boot().to_us();
        if (now - last_toggle >= 250_000) {
            last_toggle = now;
            blink_count += 1;
            pins.led.toggle();
            if (usb_controller.drivers()) |drivers| {
                cdc_write(&drivers.serial, "test blink blink blink {}\r\n", .{blink_count});
            }
        }
    }
}
