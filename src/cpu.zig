const std = @import("std");
const bus = @import("bus.zig");
const decoder = @import("decoder.zig");
const math = @import("math.zig");
const op_writer = @import("disasm_op_writer.zig");

const log = std.log.scoped(.cpu);
const I = decoder.I;
const Op = decoder.opcodes.op;

const zero_ext = math.zero_ext;
const sign_ext = math.sign_ext;

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

const Instruction = struct {
    op: decoder.opcodes.op,
    i: I,
};

pub const Cpu = struct {
    halted: bool = false,
    rf: RegisterFile = .{},
    bus: *bus.Bus,
    // Used to emulate branch delay slots:
    // step 0: next = branch, execute = nop
    // step 1: next = other, execute = branch -> set pc
    // step 2: next = target, execute = target
    next_instruction: u32 = 0,

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
        const i, const op = decoder.decode(self.next_instruction);
        self.next_instruction = self.bus.read32(self.rf.pc);

        var str_buf: [256]u8 = .{0} ** 256;
        var fbs = std.io.fixedBufferStream(str_buf[0..]);
        var w = fbs.writer();
        // const w = std.io.getStdOut().writer();
        op_writer.write_instruction(i, op, &w, false) catch {
            log.err("io error", .{});
        };

        if (i.value == 0) {
            log.debug("(NOP)", .{});
        } else {
            log.debug("{s}", .{&str_buf});
        }

        switch (op) {
            .ADDIU => self.op_addiu(i),
            .LUI => self.op_lui(i),
            .ORI => self.op_ori(i),
            .SW => self.op_sw(i),
            .SLL => self.op_sll(i),
            .J => self.op_j(i),
            else => {
                log.err("unknown instruction encountered. halted := true", .{});
                self.halted = true;
            },
        }

        self.rf.pc += 4;

        // if not NOP, print the state
        if (i.value != 0)
            self.log_state();
    }

    inline fn branch_to(self: *@This(), pc: u32) void {
        log.debug("branch to {x}", .{pc});
        self.rf.pc = pc;
    }

    // ----------------------- Instructions -----------------------

    fn op_lui(self: *@This(), i: I) void {
        self.rf.write(i.rt(), @as(u32, i.imm16()) << 16);
    }

    fn op_ori(self: *@This(), i: I) void {
        const imm32 = zero_ext(i.imm16());
        const before = self.rf.read(i.rs());
        self.rf.write(i.rt(), imm32 | before);
    }

    fn op_sll(self: *@This(), i: I) void {
        const sa = i.re();
        const res = self.rf.read(i.rt()) << sa;
        self.rf.write(i.rd(), res);
    }

    fn op_sw(self: *@This(), i: I) void {
        const dst_addr = self.rf.read(i.rs()) +% sign_ext(i.imm16());
        const v = self.rf.read(i.rt());
        self.bus.write32(dst_addr, v);
    }

    fn op_addiu(self: *@This(), i: I) void {
        const res = self.rf.read(i.rs()) +% i.imm16();
        self.rf.write(i.rt(), res);
    }

    fn op_j(self: *@This(), i: I) void {
        const instr_index = @as(u28, @intCast(i.target())) << 2;
        const new_pc = (self.rf.pc & math.bitmask_rnc(u32, 28, 4)) | instr_index;
        self.branch_to(new_pc);
    }
};
