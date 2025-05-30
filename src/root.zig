const std = @import("std");

pub const bios = @import("bios.zig");
pub const cpu = @import("cpu.zig");
pub const bus = @import("bus.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
