const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const usb_cdc = @import("./helpers/usb_cdc.zig");
const DS18B20 = microzig.drivers.sensor.DS18B20;

const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO25 = .{ .name = "led", .direction = .out },
    .GPIO22 = .{ .name = "temp", .direction = .in, .pull = .up },
    .GPIO21 = .{ .name = "heater", .direction = .out, .pull = .down },
    .GPIO20 = .{ .name = "ultra_sound", .direction = .out, .pull = .down },
};

// Change this to select the blink phase
const BLINK_INTERVAL_US: u64 = 800_000; // fast: 100ms, slow: 500_000

const Pins = @TypeOf(pin_config.apply());
var pins: Pins = undefined;
var last_toggle: u64 = 0;
var blink_count: u32 = 0;

const TEMP_THRESHOLD_MIN: f32 = 25.0;
const TEMP_THRESHOLD_MAX: f32 = 28.0;

const MAGIC_ULTRA_SOUND_VALUE: f32 = 29.0;

pub fn measure_ulta_sound(a: u32, b: u32) f32 {
    // Placeholder implementation

    return (b - a) / MAGIC_ULTRA_SOUND_VALUE;
}

pub fn trigger_ultra_sound() !void {
    var ultra_sound_gpio = rp2xxx.drivers.GPIO_Device.init(pins.ultra_sound);
    ultra_sound_gpio.write(.high) catch |err| {
        usb_cdc.write("ultra sound trigger failed: {s}\r\n", .{@errorName(err)});
        return;
    };
    usb_cdc.write("ultra sound triggered\r\n", .{});
    time.sleep_ms(10);
    ultra_sound_gpio.write(.low) catch |err| {
        usb_cdc.write("ultra sound trigger failed: {s}\r\n", .{@errorName(err)});
        return;
    };
    usb_cdc.write("ultra sound reset\r\n", .{});
}

pub fn main() !void {
    pins = pin_config.apply();
    usb_cdc.init();

    var temp_gpio = rp2xxx.drivers.GPIO_Device.init(pins.temp);
    const ds18b20 = try DS18B20.init(temp_gpio.digital_io(), rp2xxx.drivers.clock_device());

    ds18b20.write_config(.{ .resolution = .sixteenth_degree_12 }) catch |err| {
        usb_cdc.write("ds18b20 init failed: {s}\r\n", .{@errorName(err)});
    };

    var heater_gpio = rp2xxx.drivers.GPIO_Device.init(pins.heater);
    var heater_on = false;
    heater_gpio.write(.low) catch |err| {
        usb_cdc.write("heater init failed: {s}\r\n", .{@errorName(err)});
    };

    while (true) {
        usb_cdc.poll();
        const now = time.get_time_since_boot().to_us();
        if (now - last_toggle >= BLINK_INTERVAL_US) {
            last_toggle = now;
            blink_count += 1;
            pins.led.toggle();
            //usb_cdc.write("blink {}\r\n", .{blink_count});

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

            if (temp <= TEMP_THRESHOLD_MIN) {
                heater_on = true;
                heater_gpio.write(.high) catch |err| {
                    usb_cdc.write("heater write failed: {s}\r\n", .{@errorName(err)});
                    continue;
                };
            } else if (temp >= TEMP_THRESHOLD_MAX) {
                heater_on = false;
                heater_gpio.write(.low) catch |err| {
                    usb_cdc.write("heater write failed: {s}\r\n", .{@errorName(err)});
                    continue;
                };
            }

            usb_cdc.write("heater: {}\r\n", .{heater_on});

            time.sleep_ms(100);

            trigger_ultra_sound() catch |err| {
                usb_cdc.write("ultra sound trigger failed: {s}\r\n", .{@errorName(err)});
                continue;
            };
        }
    }
}
