const std = @import("std");
const lib = @import("psx_emulator_lib");

// Logging config:
const scope_levels = [_]std.log.ScopeLevel{
    .{ .scope = .decoder, .level = .warn },
};
pub const std_options = std.Options{
    .log_level = .debug,
    .log_scope_levels = &scope_levels,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var bios = try lib.bios.Bios.load("./bios/scph-1002-v20-eu.bin", allocator);
    var bus = lib.bus.Bus{ .bios = &bios };
    var cpu: lib.cpu.Cpu = .{ .bus = &bus };

    cpu.reset();

    while (true) {
        cpu.step();
    }
}
