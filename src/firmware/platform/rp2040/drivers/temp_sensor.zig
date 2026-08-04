const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const DS18B20 = microzig.drivers.sensor.DS18B20;

// Max conversion time at the sixteenth_degree_12 resolution configured below.
const CONVERSION_WAIT_MS: u32 = 750;

var gpio: rp2xxx.drivers.GPIO_Device = undefined;
var sensor: DS18B20 = undefined;

pub fn init(pin: anytype) !void {
    gpio = rp2xxx.drivers.GPIO_Device.init(pin);
    sensor = try DS18B20.init(gpio.digital_io(), rp2xxx.drivers.clock_device());
}

pub fn configure() !void {
    try sensor.write_config(.{ .resolution = .sixteenth_degree_12 });
}

// Initiates a conversion, blocks for the sensor's max conversion time, then
// reads back the temperature in Celsius.
pub fn read() !f32 {
    try sensor.initiate_temperature_conversion(.{});
    time.sleep_ms(CONVERSION_WAIT_MS);
    return sensor.read_temperature(.{});
}
