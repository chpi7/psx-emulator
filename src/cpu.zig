const std = @import("std");
const bus = @import("bus.zig");
const decoder = @import("decoder.zig");
const log = std.log.scoped(.cpu);

const RegisterFile = struct {
    r: [32]u32 = .{0} ** 32,
    pc: u32 = 0,
    hi: u32 = 0,
    lo: u32 = 0,

    pub fn format(
        self: RegisterFile,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.writeAll("\n");

        for (0..8) |r| {
            try writer.print("   r{d:02} {x:08}  r{d:02} {x:08}  r{d:02} {x:08}  r{d:02} {x:08}\n", .{
                r,      self.r[r],
                r + 8,  self.r[r + 8],
                r + 16, self.r[r + 16],
                r + 24, self.r[r + 24],
            });
        }
        try writer.print("    pc {x:08}   hi {x:08}   lo {x:08}", .{ self.pc, self.hi, self.lo });
    }
};

pub const Cpu = struct {
    rf: RegisterFile = .{},
    bus: *bus.Bus,

    pub fn log_state(self: *Cpu) void {
        log.debug("{s}", .{self.rf});
    }

    pub fn reset(self: *Cpu) void {
        self.rf.pc = 0xbfc00000; // start address of BIOS
    }

    pub fn step(self: *Cpu) void {
        const i_raw = self.bus.read(self.rf.pc);
        const instr, const mnemonic = decoder.decode(i_raw);

        log.debug("next instruction {}, {}", .{ instr, mnemonic });
    }
};
