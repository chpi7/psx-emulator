const std = @import("std");
const bus = @import("bus.zig");
const decoder = @import("decoder.zig");

const log = std.log.scoped(.cpu);
const I = decoder.I;
const Op = decoder.opcodes.op;

const RegisterFile = struct {
    r: [32]u32 = .{0} ** 32,
    pc: u32 = 0,
    hi: u32 = 0,
    lo: u32 = 0,

    pub fn read(self: *const @This(), i: u5) u32 {
        return self.r[i];
    }

    pub fn write(self: *@This(), i: u5, v: u32) void {
        self.r[i] = v;
        // BIOS uses write to 0 as a sink, therefore ensure that it stays zero.
        self.r[0] = 0;
    }

    pub fn format(self: RegisterFile, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
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

fn zero_ext(v: anytype) u32 {
    const T = @TypeOf(v);
    comptime {
        if (@typeInfo(T).int.signedness != .unsigned) {
            @compileError("zero_extend only works for unsigned types");
        }
        if (@bitSizeOf(T) >= 32) {
            @compileError("zero_extend only works for types smaller than 32 bits");
        }
    }
    return @as(u32, v);
}

pub const Cpu = struct {
    halted: bool = false,
    rf: RegisterFile = .{},
    bus: *bus.Bus,

    pub fn log_state(self: *Cpu) void {
        log.debug("{s}", .{self.rf});
    }

    pub fn reset(self: *Cpu) void {
        self.rf.pc = 0xbfc00000; // start address of BIOS
        for (0..32) |i| {
            self.rf.write(@truncate(i), 0xdeadbeef);
        }
        log.debug("reset", .{});
        self.log_state();
    }

    pub fn step(self: *Cpu) void {
        const i_raw = self.bus.read32(self.rf.pc);
        const i, const op = decoder.decode(i_raw);

        log.debug("decoded {}, {}", .{ op, i });

        switch (op) {
            .LUI => self.op_lui(i),
            .ORI => self.op_ori(i),
            .SW => self.op_sw(i),
            else => {
                log.err("unknown instruction encountered. halted := true", .{});
                self.halted = true;
            },
        }

        self.rf.pc += 4;

        // self.log_state();
    }

    // ----------------------- Instructions -----------------------

    fn op_lui(self: *@This(), i: I) void {
        self.rf.write(i.I.rt, @as(u32, i.I.imm) << 16);
    }

    fn op_ori(self: *@This(), i: I) void {
        const imm32 = zero_ext(i.I.rt);
        self.rf.write(i.I.rt, imm32 | self.rf.read(i.I.rs));
    }

    fn op_sw(self: *@This(), i: I) void {
        const dst_addr = self.rf.read(i.I.rs) + i.I.imm;
        const v = self.rf.read(i.I.rt);
        self.bus.write32(dst_addr, v);
    }
};
