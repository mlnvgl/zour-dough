const rp2xxx = @import("microzig").hal;
pub const HeaterState = @import("./heater_control.zig").HeaterState;

var gpio: rp2xxx.drivers.GPIO_Device = undefined;

pub fn init(pin: anytype) void {
    gpio = rp2xxx.drivers.GPIO_Device.init(pin);
}

// Mechanical GPIO write only; when/why the heater should be on is a control
// decision that stays with the caller.
pub fn set(state: HeaterState) rp2xxx.drivers.GPIO_Device.WriteError!void {
    try gpio.write(if (state == .on) .high else .low);
}
