const std = @import("std");
const microzig = @import("microzig");

const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

pub fn build(b: *std.Build) void {
    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;

    const firmware = mb.add_firmware(.{
        .name = "blinky",
        .target = mb.ports.rp2xxx.boards.raspberrypi.pico,
        .optimize = .ReleaseSmall,
        .root_source_file = b.path("src/main.zig"),
    });

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const flashy = b.addExecutable(.{
        .name = "flashy",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/flash.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(flashy);

    const run_flashy_step = b.step("run-flashy", "runs flash script");
    const run_flashy_cmd = b.addRunArtifact(flashy);
    run_flashy_step.dependOn(&run_flashy_cmd.step);

    const serial_logger = b.addExecutable(.{
        .name = "serial-logger",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/serial-logger.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(serial_logger);

    const run_seriallogger_step = b.step("run-serial-logger", "runs serial logger script");
    const run_seriallogger_cmd = b.addRunArtifact(serial_logger);
    run_seriallogger_step.dependOn(&run_seriallogger_cmd.step);

    const power_switch_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/power_switch.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_power_switch_tests = b.addRunArtifact(power_switch_tests);
    const test_step = b.step("test", "run unit tests");
    test_step.dependOn(&run_power_switch_tests.step);

    const heater_control_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/heater_control.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_heater_control_tests = b.addRunArtifact(heater_control_tests);
    test_step.dependOn(&run_heater_control_tests.step);

    // We call this twice to demonstrate that the default binary output for
    // RP2040 is UF2, but we can also output other formats easily
    mb.install_firmware(firmware, .{});
    mb.install_firmware(firmware, .{ .format = .elf });
}
