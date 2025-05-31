const std = @import("std");
const lib = @import("psx_emulator_lib");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var bios = try lib.bios.Bios.load("./bios/scph-1002-v20-eu.bin", allocator);
    var bus = lib.bus.Bus{ .bios = &bios };
    var cpu: lib.cpu.Cpu = .{ .bus = &bus };

    cpu.reset();
    cpu.log_state();

    cpu.step();
}
