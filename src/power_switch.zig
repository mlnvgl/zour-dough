const rp2xxx = @import("microzig").hal;
const PowerSwitch = @import("./power_switch_control.zig").PowerSwitch;

var gpio: rp2xxx.drivers.GPIO_Device = undefined;

pub fn init(pin: anytype) void {
    gpio = rp2xxx.drivers.GPIO_Device.init(pin);
}

// Wired to ground, so pull-up reads .low on the pin when the switch is on.
pub fn read(power_switch: *PowerSwitch) void {
    const switch_is_on = (gpio.read() catch .high) == .low;
    if (switch_is_on) power_switch.switchOn() else power_switch.switchOff();
}
