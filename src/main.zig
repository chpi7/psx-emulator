const std = @import("std");
const lib = @import("psx_emulator_lib");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var bios = try lib.bios.Bios.load("./bios/scph-1002-v20-eu.bin", allocator);
    var bus = lib.bus.Bus{ .bios = &bios };
    var cpu: lib.cpu.R3000A = .{ .bus = &bus };

    cpu.reset();

    std.log.debug("bios.data[0]=0x{x}", .{bios.data[0]});
    std.log.debug("r0 = 0x{x}", .{cpu.rf.r[0]});

    cpu.step();
}
