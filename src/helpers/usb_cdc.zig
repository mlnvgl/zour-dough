const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const usb = microzig.core.usb;

const USB_Device = rp2xxx.usb.Polled(.{});
const USB_Serial = usb.drivers.CDC;

var device: USB_Device = undefined;

var controller: usb.DeviceController(.{
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

var tx_buf: [256]u8 = undefined;
var rx_buf: [256]u8 = undefined;

pub fn init() void {
    device = .init();
}

pub fn poll() void {
    device.poll(&controller);
}

pub fn write(comptime fmt: []const u8, args: anytype) void {
    const drivers = controller.drivers() orelse return;
    var tx = std.fmt.bufPrint(&tx_buf, fmt, args) catch return;
    const deadline = time.get_time_since_boot().to_us() + 10_000;
    while (tx.len > 0) {
        tx = tx[drivers.serial.write(tx)..];
        device.poll(&controller);
        if (time.get_time_since_boot().to_us() >= deadline) return;
    }
    while (!drivers.serial.flush()) {
        device.poll(&controller);
        if (time.get_time_since_boot().to_us() >= deadline) break;
    }
}

pub fn read() []const u8 {
    const drivers = controller.drivers() orelse return &.{};
    var len: usize = 0;
    while (true) {
        const n = drivers.serial.read(rx_buf[len..]);
        len += n;
        if (n == 0) break;
    }
    return rx_buf[0..len];
}
