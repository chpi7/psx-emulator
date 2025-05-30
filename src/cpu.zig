const std = @import("std");
const bus = @import("bus.zig");
const decoder = @import("decoder.zig");

const RegisterFile = struct {
    r: [32]u32 = .{0} ** 32,
    pc: u32 = 0,
    hi: u32 = 0,
    lo: u32 = 0,
};

pub const R3000A = struct {
    rf: RegisterFile = .{},
    bus: *bus.Bus,

    pub fn reset(self: *R3000A) void {
        self.rf.pc = 0xbfc00000; // start address of BIOS
    }

    pub fn step(self: *R3000A) void {
        const i_raw = self.bus.read(self.rf.pc);
        const instr, const mnemonic = decoder.decode(i_raw);

        std.log.debug("next instruction {}, {}", .{ instr, mnemonic });
    }
};
