const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const usb_cdc = @import("./helpers/usb_cdc.zig");
const DS18B20 = microzig.drivers.sensor.DS18B20;
const PowerSwitch = @import("./power_switch.zig").PowerSwitch;
const status_led = @import("./status_led.zig");
const Ticker = @import("./ticker.zig").Ticker;
const heater = @import("./heater.zig");

const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO22 = .{ .name = "temp", .direction = .in, .pull = .up },
    .GPIO21 = .{ .name = "heater", .direction = .out, .pull = .down },
    .GPIO20 = .{ .name = "ultra_sound_trigger", .direction = .out, .pull = .down },
    .GPIO19 = .{ .name = "ultra_sound_echo", .direction = .in, .pull = .down },
    // Baker's physical on/off toggle switch. Wired to ground, so pull-up
    // reads .low on the pin when the switch is on.
    .GPIO18 = .{ .name = "power_switch", .direction = .in, .pull = .up },
};

// Interval for the main loop's periodic work (LED heartbeat, temp/heater
// check, ultrasound read). fast: 100ms, slow: 500_000
const MAIN_LOOP_INTERVAL_US: u64 = 800_000;

const Pins = @TypeOf(pin_config.apply());
var pins: Pins = undefined;
var ticker: Ticker = .{ .interval_us = MAIN_LOOP_INTERVAL_US };

const TEMP_THRESHOLD_MIN: f32 = 25.0;
const TEMP_THRESHOLD_MAX: f32 = 28.0;

const ULTRA_SOUND_TRIGGER_US: u64 = 10;
const ULTRA_SOUND_SETTLE_US: u64 = 2;
const ULTRA_SOUND_ECHO_TIMEOUT_US: u64 = 35_000;
const SOUND_SPEED_CM_PER_US: f32 = 0.0343;

const UltraSoundError =
    rp2xxx.drivers.GPIO_Device.SetDirError ||
    rp2xxx.drivers.GPIO_Device.WriteError ||
    rp2xxx.drivers.GPIO_Device.ReadError ||
    error{ EchoRiseTimeout, EchoFallTimeout };

fn waitForEchoStart(echo_gpio: *rp2xxx.drivers.GPIO_Device) UltraSoundError!u64 {
    const wait_started_at = time.get_time_since_boot().to_us();

    while (try echo_gpio.read() == .low) {
        usb_cdc.poll();
        if (time.get_time_since_boot().to_us() - wait_started_at >= ULTRA_SOUND_ECHO_TIMEOUT_US) {
            return error.EchoRiseTimeout;
        }
    }

    return time.get_time_since_boot().to_us();
}

fn waitForEchoEnd(echo_gpio: *rp2xxx.drivers.GPIO_Device) UltraSoundError!u64 {
    const wait_started_at = time.get_time_since_boot().to_us();

    while (try echo_gpio.read() == .high) {
        usb_cdc.poll();
        if (time.get_time_since_boot().to_us() - wait_started_at >= ULTRA_SOUND_ECHO_TIMEOUT_US) {
            return error.EchoFallTimeout;
        }
    }

    return time.get_time_since_boot().to_us();
}

pub fn measure_ultra_sound() UltraSoundError!f32 {
    var trigger_gpio = rp2xxx.drivers.GPIO_Device.init(pins.ultra_sound_trigger);
    var echo_gpio = rp2xxx.drivers.GPIO_Device.init(pins.ultra_sound_echo);

    try trigger_gpio.set_direction(.output);
    try echo_gpio.set_direction(.input);
    try trigger_gpio.write(.low);
    time.sleep_us(ULTRA_SOUND_SETTLE_US);

    try trigger_gpio.write(.high);
    time.sleep_us(ULTRA_SOUND_TRIGGER_US);
    try trigger_gpio.write(.low);

    const echo_started_at = try waitForEchoStart(&echo_gpio);
    const echo_ended_at = try waitForEchoEnd(&echo_gpio);
    const echo_duration_us = echo_ended_at - echo_started_at;

    return @as(f32, @floatFromInt(echo_duration_us)) * SOUND_SPEED_CM_PER_US / 2.0;
}

pub fn main() !void {
    pins = pin_config.apply();
    try status_led.init();
    status_led.bootBlink();
    usb_cdc.init();

    var temp_gpio = rp2xxx.drivers.GPIO_Device.init(pins.temp);
    const ds18b20 = try DS18B20.init(temp_gpio.digital_io(), rp2xxx.drivers.clock_device());

    ds18b20.write_config(.{ .resolution = .sixteenth_degree_12 }) catch |err| {
        usb_cdc.write("ds18b20 init failed: {s}\r\n", .{@errorName(err)});
    };

    heater.init(pins.heater);
    var heater_state: heater.HeaterState = .off;
    heater.set(heater_state) catch |err| {
        usb_cdc.write("heater init failed: {s}\r\n", .{@errorName(err)});
    };

    var power_switch_gpio = rp2xxx.drivers.GPIO_Device.init(pins.power_switch);
    var power_switch = PowerSwitch{};

    while (true) {
        usb_cdc.poll();
        const now = time.get_time_since_boot().to_us();

        const switch_is_on = (power_switch_gpio.read() catch .high) == .low;
        if (switch_is_on) power_switch.switchOn() else power_switch.switchOff();

        if (ticker.ready(now)) {
            status_led.toggle();

            ds18b20.initiate_temperature_conversion(.{}) catch |err| {
                usb_cdc.write("conversion failed: {s}\r\n", .{@errorName(err)});
                continue;
            };
            time.sleep_ms(750);
            const temp = ds18b20.read_temperature(.{}) catch |err| {
                usb_cdc.write("read failed: {s}\r\n", .{@errorName(err)});
                continue;
            };
            usb_cdc.write("temp: {}\r\n", .{temp});

            if (power_switch.state == .off) {
                heater_state = .off;
                heater.set(heater_state) catch |err| {
                    usb_cdc.write("heater write failed: {s}\r\n", .{@errorName(err)});
                    continue;
                };
            } else if (temp <= TEMP_THRESHOLD_MIN) {
                heater_state = .on;
                heater.set(heater_state) catch |err| {
                    usb_cdc.write("heater write failed: {s}\r\n", .{@errorName(err)});
                    continue;
                };
            } else if (temp >= TEMP_THRESHOLD_MAX) {
                heater_state = .off;
                heater.set(heater_state) catch |err| {
                    usb_cdc.write("heater write failed: {s}\r\n", .{@errorName(err)});
                    continue;
                };
            }

            usb_cdc.write("power: {s}\r\n", .{@tagName(power_switch.state)});
            usb_cdc.write("heater: {s}\r\n", .{@tagName(heater_state)});

            time.sleep_ms(100);

            const distance_cm = measure_ultra_sound() catch |err| {
                usb_cdc.write("ultra sound read failed: {s}\r\n", .{@errorName(err)});
                continue;
            };
            usb_cdc.write("distance_cm: {}\r\n", .{distance_cm});
        }
    }
}
