const rp2xxx = @import("microzig").hal;
const time = rp2xxx.time;
const usb_cdc = @import("./helpers/usb_cdc.zig");

const TRIGGER_US: u64 = 10;
const SETTLE_US: u64 = 2;
const ECHO_TIMEOUT_US: u64 = 35_000;
const SOUND_SPEED_CM_PER_US: f32 = 0.0343;

pub const Error =
    rp2xxx.drivers.GPIO_Device.SetDirError ||
    rp2xxx.drivers.GPIO_Device.WriteError ||
    rp2xxx.drivers.GPIO_Device.ReadError ||
    error{ EchoRiseTimeout, EchoFallTimeout };

var trigger_gpio: rp2xxx.drivers.GPIO_Device = undefined;
var echo_gpio: rp2xxx.drivers.GPIO_Device = undefined;

pub fn init(trigger_pin: anytype, echo_pin: anytype) void {
    trigger_gpio = rp2xxx.drivers.GPIO_Device.init(trigger_pin);
    echo_gpio = rp2xxx.drivers.GPIO_Device.init(echo_pin);
}

fn waitForEchoStart() Error!u64 {
    const wait_started_at = time.get_time_since_boot().to_us();

    while (try echo_gpio.read() == .low) {
        usb_cdc.poll();
        if (time.get_time_since_boot().to_us() - wait_started_at >= ECHO_TIMEOUT_US) {
            return error.EchoRiseTimeout;
        }
    }

    return time.get_time_since_boot().to_us();
}

fn waitForEchoEnd() Error!u64 {
    const wait_started_at = time.get_time_since_boot().to_us();

    while (try echo_gpio.read() == .high) {
        usb_cdc.poll();
        if (time.get_time_since_boot().to_us() - wait_started_at >= ECHO_TIMEOUT_US) {
            return error.EchoFallTimeout;
        }
    }

    return time.get_time_since_boot().to_us();
}

// Distance to the dough surface in centimeters.
pub fn measure() Error!f32 {
    try trigger_gpio.set_direction(.output);
    try echo_gpio.set_direction(.input);
    try trigger_gpio.write(.low);
    time.sleep_us(SETTLE_US);

    try trigger_gpio.write(.high);
    time.sleep_us(TRIGGER_US);
    try trigger_gpio.write(.low);

    const echo_started_at = try waitForEchoStart();
    const echo_ended_at = try waitForEchoEnd();
    const echo_duration_us = echo_ended_at - echo_started_at;

    return @as(f32, @floatFromInt(echo_duration_us)) * SOUND_SPEED_CM_PER_US / 2.0;
}
