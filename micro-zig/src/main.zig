const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const DS18B20 = microzig.drivers.sensor.DS18B20;

// const gpio = rp2xxx.gpio;
// const uart = rp2xxx.uart.instance.num(0);
// const uart_tx_pin = gpio.num(0);

// Compile-time pin configuration
const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO25 = .{
        .name = "led",
        .direction = .out,
    },
    .GPIO20 = .{
        .name = "heater_output",
        .direction = .out,
    },
    .GPIO22 = .{
        .name = "ds18b20",
        .direction = .in,
        .pull = .up,
    },
};

// pub const microzig_options = microzig.Options{
//     .log_level = .debug,
//     .logFn = rp2xxx.uart.log,
// };

pub fn main() !void {
    const pins = pin_config.apply();
    var status: u1 = 0;

    // var ds18b20_gpio = rp2xxx.drivers.GPIO_Device.init(pins.ds18b20);
    // const clock_device = rp2xxx.drivers.clock_device();

    // const ds18b20 = try DS18B20.init(ds18b20_gpio.digital_io(), clock_device);

    // set desired resolution
    //try ds18b20.write_config(.{ .resolution = .sixteenth_degree_12 });

    while (true) {
        pins.heater_output.put(status);
        pins.led.toggle();
        time.sleep_ms(2500);
        status = 1 - status; // Toggle between 0 and 1

        //try ds18b20.initiate_temperature_conversion(.{});

        // wait for conversion to complete (depends on resolution)
        time.sleep_ms(750);

        // read temperature
        //const temperature = try ds18b20.read_temperature(.{});
        //std.log.info("what {any}", .{temperature});

        // if (temperature > 25.0) {
        //     std.debug.print("Temperature is above 25°C: {d}°C\n", .{temperature});
        //     pins.heater_output.put(0);
        // } else {
        //     std.debug.print("Temperature is at or below 25°C: {d}°C\n", .{temperature});
        // }
    }
}
