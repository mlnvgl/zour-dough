const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const gpio = rp2xxx.gpio;
const rotary_control = @import("../../../domain/rotary_control.zig");
const Level = rotary_control.Level;

const EDGES = gpio.IrqEvents{ .rise = 1, .fall = 1 };

var sw_pin: gpio.Pin = undefined;
var clk_pin: gpio.Pin = undefined;
var dt_pin: gpio.Pin = undefined;

var quadrature: rotary_control.Quadrature = .{};
var counts: i32 = 0;

pub fn init(sw: gpio.Pin, clk: gpio.Pin, dt: gpio.Pin) void {
    sw_pin = sw;
    clk_pin = clk;
    dt_pin = dt;

    _ = quadrature.update(readClk(), readDt());

    clk_pin.set_irq_enabled(EDGES, true);
    dt_pin.set_irq_enabled(EDGES, true);
    microzig.interrupt.enable(.IO_IRQ_BANK0);
}

// Runs from RAM so the handler never waits on flash. The encoder is the only
// input in the system that loses information when a sample is missed, so it is
// decoded here rather than in the main loop, which stalls for tens of
// milliseconds on the display flush and the one-wire reads.
pub fn onGpioIrq() linksection(".ram_text") callconv(.c) void {
    var iter = gpio.IrqEventIter{};
    while (iter.next()) |_| {}
    counts += quadrature.update(readClk(), readDt());
}

pub fn takeCounts() i32 {
    const section = microzig.interrupt.enter_critical_section();
    defer section.leave();

    const taken = counts;
    counts = 0;
    return taken;
}

pub fn readSw() Level {
    return level(sw_pin);
}

fn readClk() Level {
    return level(clk_pin);
}

fn readDt() Level {
    return level(dt_pin);
}

fn level(pin: gpio.Pin) Level {
    return if (pin.read() == 1) .high else .low;
}
