const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const DS18B20 = microzig.drivers.sensor.DS18B20;

var gpio: rp2xxx.drivers.GPIO_Device = undefined;
var sensor: DS18B20 = undefined;

pub fn init(pin: anytype) !void {
    gpio = rp2xxx.drivers.GPIO_Device.init(pin);
    sensor = try DS18B20.init(gpio.digital_io(), rp2xxx.drivers.clock_device());
}

pub fn configure() !void {
    try sensor.write_config(.{ .resolution = .sixteenth_degree_12 });
}

pub fn startConversion() !void {
    try sensor.initiate_temperature_conversion(.{});
}

pub fn readTemperature() !f32 {
    return sensor.read_temperature(.{});
}
