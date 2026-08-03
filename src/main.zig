const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const usb_cdc = @import("./helpers/usb_cdc.zig");
const PowerSwitch = @import("./power_switch.zig").PowerSwitch;
const status_led = @import("./status_led.zig");
const Ticker = @import("./ticker.zig").Ticker;
const heater = @import("./heater.zig");
const heater_control = @import("./heater_control.zig");
const temp_sensor = @import("./temp_sensor.zig");
const ultra_sound = @import("./ultra_sound.zig");

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

pub fn main() !void {
    pins = pin_config.apply();
    try status_led.init();
    status_led.bootBlink();
    usb_cdc.init();

    try temp_sensor.init(pins.temp);
    temp_sensor.configure() catch |err| {
        usb_cdc.write("ds18b20 init failed: {s}\r\n", .{@errorName(err)});
    };

    ultra_sound.init(pins.ultra_sound_trigger, pins.ultra_sound_echo);

    heater.init(pins.heater);
    var heater_state: heater_control.HeaterState = .off;
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

            const temp = temp_sensor.read() catch |err| {
                usb_cdc.write("temp read failed: {s}\r\n", .{@errorName(err)});
                continue;
            };
            usb_cdc.write("temp: {}\r\n", .{temp});

            heater_state = heater_control.decide(temp, power_switch.state, heater_state);
            heater.set(heater_state) catch |err| {
                usb_cdc.write("heater write failed: {s}\r\n", .{@errorName(err)});
                continue;
            };

            usb_cdc.write("power: {s}\r\n", .{@tagName(power_switch.state)});
            usb_cdc.write("heater: {s}\r\n", .{@tagName(heater_state)});

            time.sleep_ms(100);

            const distance_cm = ultra_sound.measure() catch |err| {
                usb_cdc.write("ultra sound read failed: {s}\r\n", .{@errorName(err)});
                continue;
            };
            usb_cdc.write("distance_cm: {}\r\n", .{distance_cm});
        }
    }
}
