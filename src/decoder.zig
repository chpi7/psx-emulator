const std = @import("std");
pub const opcodes = @import("opcodes.zig");

const log = std.log.scoped(.decoder);

const mn = opcodes.op;
const sop = opcodes.subop;
const pop = opcodes.primary;

const Type = enum { I, J, R };

const I_I = packed struct(u32) {
    imm: u16 = 0,
    rt: u5 = 0,
    rs: u5 = 0,
    op: u6 = 0,
};

const I_J = packed struct(u32) {
    target: u26 = 0,
    op: u6 = 0,

    pub fn format(self: *const @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{{ target = {x} }}", .{self.target});
    }
};

const I_R = packed struct(u32) {
    funct: u6 = 0,
    re: u5 = 0,
    rd: u5 = 0,
    rt: u5 = 0,
    rs: u5 = 0,
    op: u6 = 0,
};

pub const I = union(Type) {
    I: I_I,
    J: I_J,
    R: I_R,

    pub fn format(self: I, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        // Get rid of some extra bloat in the generated format function.
        _ = fmt;
        _ = options;
        try switch (self) {
            I.I => |x| writer.print("{}", .{x}),
            I.J => |x| writer.print("{}", .{x}),
            I.R => |x| writer.print("{}", .{x}),
        };
    }
};

fn get_type_special(i: I) Type {
    const subop: u6 = @truncate(@as(u32, @bitCast(i.R)));
    if (subop == @intFromEnum(sop.JR)) {
        return Type.R;
    } else {
        return Type.R;
    }
}

fn get_type(i: I, op: mn) Type {
    if (!opcodes.is_valid_primary(i.R.op)) {
        // Return anything just so we can pipe it through to the disassembler.
        // Use J because that doesn't have anything else to decode.
        return Type.J;
    }

    switch (@as(opcodes.primary, @enumFromInt(i.R.op))) {
        pop.SPECIAL => return get_type_special(i),
        pop.BcondZ => return Type.I,
        pop.JAL, pop.J => return Type.J,
        else => {},
    }

    // If it isn't coprocessor now, it is Type I for sure:
    // (Coprocessor instruction have bit 5 set.)
    if (0b010000 & i.R.op == 0) {
        return Type.I;
    }

    return switch (op) {
        mn.COPz => Type.J, // it isn't really a "j"ump instruction but also has the 26bit imm in the same place.
        mn.MFCz, mn.CFCz, mn.MTCz, mn.CTCz, mn.LWCz, mn.SWCz => Type.R,
        else => Type.I,
    };
}

fn get_op_branch(i: I) mn {
    const ge = (0b00001 & i.R.rt) != 0;
    const mid_nz = (0b01110 & i.R.rt) != 0;

    return switch (i.R.rt) {
        0b00000 => mn.BLTZ,
        0b00001 => mn.BGEZ,
        0b10000 => mn.BLTZAL,
        0b10001 => mn.BGEZAL,
        else => if (mid_nz) if (ge) mn.BGEZ else mn.BLTZ else unreachable,
    };
}

fn get_op_copz(i: I) mn {
    std.debug.assert((i.R.op & 0b110000) == 0b010000);
    return switch (i.R.rs) {
        0b00000 => mn.MFCz,
        0b00010 => mn.CFCz,
        0b00100 => mn.MTCz,
        0b00110 => mn.CTCz,
        0b01000 => switch (i.R.rt) {
            0 => mn.BCzF,
            1 => mn.BCzT,
            else => mn.ILLEGAL,
        },
        0b10000 => mn.COPz,
        else => mn.ILLEGAL,
    };
}

fn get_op(i: I) mn {
    return switch (i.R.op) {
        0x00 => opcodes.resolve_subop(i.R.funct),
        0x01 => get_op_branch(i),
        0x02...0x0f => opcodes.resolve_op(i.R.op),
        0x10...0x13 => get_op_copz(i),
        0x20...0x26 => opcodes.resolve_op(i.R.op),
        0x28...0x2b => opcodes.resolve_op(i.R.op),
        0x2e => opcodes.resolve_op(i.R.op),
        0x30...0x33 => opcodes.resolve_op(i.R.op),
        0x38...0x3b => opcodes.resolve_op(i.R.op),
        else => mn.ILLEGAL,
    };
}

pub fn decode(in: u32) struct { I, mn } {
    log.debug("decode 0x{x:08}", .{in});

    std.debug.assert(@bitOffsetOf(I_I, "op") == 26);
    std.debug.assert(@bitOffsetOf(I_J, "op") == 26);
    std.debug.assert(@bitOffsetOf(I_R, "op") == 26);

    // To decode, use R format to get access to primary op and subop.
    const tmp: I = I{ .R = @bitCast(in) };
    const op = get_op(tmp);
    const t = get_type(tmp, op);

    const instr = switch (t) {
        Type.I => I{ .I = @bitCast(in) },
        Type.J => I{ .J = @bitCast(in) },
        Type.R => I{ .R = @bitCast(in) },
    };

    return .{ instr, op };
}

// ---------------------------- TESTS ----------------------------

const tst = std.testing;

const TC = struct {
    input: u32,
    expect: struct { op: mn, i: union(Type) {
        I: struct { imm: u16 = 0, rt: u5 = 0, rs: u5 = 0 },
        J: struct { target: u26 = 0 },
        R: struct { funct: u6 = 0, re: u5 = 0, rd: u5 = 0, rt: u5 = 0, rs: u5 = 0 },
    } },

    pub fn check(self: *const @This(), instr: I, op: mn) !void {
        try std.testing.expectEqual(self.expect.op, op);
        if (op == mn.ILLEGAL) {
            // Don't care about the rest if it is illegal.
            return;
        }

        const tag_exp = std.meta.activeTag(self.expect.i);
        const tag_act = std.meta.activeTag(instr);
        try std.testing.expectEqual(tag_exp, tag_act);

        switch (self.expect.i) {
            .I => |v| {
                try std.testing.expectEqual(v.rs, instr.I.rs);
                try std.testing.expectEqual(v.rt, instr.I.rt);
                try std.testing.expectEqual(v.imm, instr.I.imm);
            },
            .J => |v| {
                try std.testing.expectEqual(v.target, instr.J.target);
            },
            .R => |v| {
                try std.testing.expectEqual(v.rs, instr.R.rs);
                try std.testing.expectEqual(v.rt, instr.R.rt);
                try std.testing.expectEqual(v.rd, instr.R.rd);
                try std.testing.expectEqual(v.re, instr.R.re);
                // Dont check this, we use it to find op, which we already check above.
                // try std.testing.expectEqual(v.funct, instr.R.funct);
            },
        }
    }
};

fn iterate_testcases(testcases: []const TC) !void {
    for (testcases) |t| {
        const instr, const op = decode(t.input);
        try t.check(instr, op);
    }
}

test "shift-imm" {
    const testcases = [_]TC{
        .{
            .input = 0b000000_00000_00000_00000_01010_000000,
            .expect = .{ .op = mn.SLL, .i = .{ .R = .{ .re = 0b01010 } } },
        },
        .{
            .input = 0b000000_00000_00000_00000_01010_000001,
            .expect = .{ .op = mn.ILLEGAL, .i = .{ .R = .{ .re = 0b01010 } } },
        },
        .{
            .input = 0b000000_00000_00000_00000_01010_000010,
            .expect = .{ .op = mn.SRL, .i = .{ .R = .{ .re = 0b01010 } } },
        },
        .{
            .input = 0b000000_00000_00000_00000_01010_000011,
            .expect = .{ .op = mn.SRA, .i = .{ .R = .{ .re = 0b01010 } } },
        },
    };

    try iterate_testcases(&testcases);
}

test "shift-reg" {
    const testcases = [_]TC{
        .{
            .input = 0b000000_00000_00000_00000_01010_000100,
            .expect = .{ .op = mn.SLLV, .i = .{ .R = .{ .re = 0b01010 } } },
        },
        .{
            .input = 0b000000_00000_00000_00000_01010_000101,
            .expect = .{ .op = mn.ILLEGAL, .i = .{ .R = .{ .re = 0b01010 } } },
        },
        .{
            .input = 0b000000_00000_00000_00000_01010_000110,
            .expect = .{ .op = mn.SRLV, .i = .{ .R = .{ .re = 0b01010 } } },
        },
        .{
            .input = 0b000000_00000_00000_00000_01010_000111,
            .expect = .{ .op = mn.SRAV, .i = .{ .R = .{ .re = 0b01010 } } },
        },
    };

    try iterate_testcases(&testcases);
}

test "jr/jalr" {
    const testcases = [_]TC{
        .{
            .input = 0b000000_00001_00000_00000_00000_001000,
            .expect = .{ .op = mn.JR, .i = .{ .R = .{ .rs = 1 } } },
        },
        .{
            .input = 0b000000_00001_00000_00010_00000_001001,
            .expect = .{ .op = mn.JALR, .i = .{ .R = .{ .rs = 1, .rd = 2 } } },
        },
    };

    try iterate_testcases(&testcases);
}

test "sys/brk" {
    const testcases = [_]TC{
        .{
            .input = 0b000000_00000_00000_00000_00000_001100,
            .expect = .{ .op = mn.SYSCALL, .i = .{ .R = .{} } },
        },
        .{
            .input = 0b000000_00000_00000_00000_00000_001101,
            .expect = .{ .op = mn.BREAK, .i = .{ .R = .{} } },
        },
    };

    try iterate_testcases(&testcases);
}

test "mfhi/mflo" {
    const testcases = [_]TC{
        .{
            .input = 0b000000_00000_00000_00001_00000_010000,
            .expect = .{ .op = mn.MFHI, .i = .{ .R = .{ .rd = 1 } } },
        },
        .{
            .input = 0b000000_00000_00000_00010_00000_010010,
            .expect = .{ .op = mn.MFLO, .i = .{ .R = .{ .rd = 2 } } },
        },
    };

    try iterate_testcases(&testcases);
}

test "mthi/mtlo" {
    const testcases = [_]TC{
        .{
            .input = 0b000000_00000_00000_00001_00000_010001,
            .expect = .{ .op = mn.MTHI, .i = .{ .R = .{ .rd = 1 } } },
        },
        .{
            .input = 0b000000_00000_00000_00010_00000_010011,
            .expect = .{ .op = mn.MTLO, .i = .{ .R = .{ .rd = 2 } } },
        },
    };

    try iterate_testcases(&testcases);
}

test "mul/div" {
    const testcases = [_]TC{
        .{
            .input = 0b000000_00001_00010_00000_00000_011000,
            .expect = .{ .op = mn.MULT, .i = .{ .R = .{ .rs = 1, .rt = 2 } } },
        },
        .{
            .input = 0b000000_00001_00010_00000_00000_011001,
            .expect = .{ .op = mn.MULTU, .i = .{ .R = .{ .rs = 1, .rt = 2 } } },
        },
        .{
            .input = 0b000000_00001_00010_00000_00000_011010,
            .expect = .{ .op = mn.DIV, .i = .{ .R = .{ .rs = 1, .rt = 2 } } },
        },
        .{
            .input = 0b000000_00001_00010_00000_00000_011011,
            .expect = .{ .op = mn.DIVU, .i = .{ .R = .{ .rs = 1, .rt = 2 } } },
        },
    };

    try iterate_testcases(&testcases);
}

test "alu-reg" {
    const testcases = [_]TC{
        .{
            .input = 0b000000_00001_00010_00100_00000_100000,
            .expect = .{ .op = mn.ADD, .i = .{ .R = .{ .rs = 1, .rt = 2, .rd = 4 } } },
        },
        .{
            .input = 0b000000_00001_00010_00100_00000_100001,
            .expect = .{ .op = mn.ADDU, .i = .{ .R = .{ .rs = 1, .rt = 2, .rd = 4 } } },
        },
        .{
            .input = 0b000000_00001_00010_00100_00000_100010,
            .expect = .{ .op = mn.SUB, .i = .{ .R = .{ .rs = 1, .rt = 2, .rd = 4 } } },
        },
        .{
            .input = 0b000000_00001_00010_00100_00000_100011,
            .expect = .{ .op = mn.SUBU, .i = .{ .R = .{ .rs = 1, .rt = 2, .rd = 4 } } },
        },
        .{
            .input = 0b000000_00001_00010_00100_00000_100100,
            .expect = .{ .op = mn.AND, .i = .{ .R = .{ .rs = 1, .rt = 2, .rd = 4 } } },
        },
        .{
            .input = 0b000000_00001_00010_00100_00000_100101,
            .expect = .{ .op = mn.OR, .i = .{ .R = .{ .rs = 1, .rt = 2, .rd = 4 } } },
        },
        .{
            .input = 0b000000_00001_00010_00100_00000_100110,
            .expect = .{ .op = mn.XOR, .i = .{ .R = .{ .rs = 1, .rt = 2, .rd = 4 } } },
        },
        .{
            .input = 0b000000_00001_00010_00100_00000_100111,
            .expect = .{ .op = mn.NOR, .i = .{ .R = .{ .rs = 1, .rt = 2, .rd = 4 } } },
        },

        .{
            .input = 0b000000_00001_00010_00100_00000_101000,
            .expect = .{ .op = mn.ILLEGAL, .i = .{ .R = .{} } },
        },
        .{
            .input = 0b000000_00001_00010_00100_00000_101001,
            .expect = .{ .op = mn.ILLEGAL, .i = .{ .R = .{} } },
        },
        .{
            .input = 0b000000_00001_00010_00100_00000_101010,
            .expect = .{ .op = mn.SLT, .i = .{ .R = .{ .rs = 1, .rt = 2, .rd = 4 } } },
        },
        .{
            .input = 0b000000_00001_00010_00100_00000_101011,
            .expect = .{ .op = mn.SLTU, .i = .{ .R = .{ .rs = 1, .rt = 2, .rd = 4 } } },
        },
        .{
            .input = 0b000000_00001_00010_00100_00000_101100,
            .expect = .{ .op = mn.ILLEGAL, .i = .{ .R = .{} } },
        },
        .{
            .input = 0b000000_00001_00010_00100_00000_101101,
            .expect = .{ .op = mn.ILLEGAL, .i = .{ .R = .{} } },
        },
        .{
            .input = 0b000000_00001_00010_00100_00000_101110,
            .expect = .{ .op = mn.ILLEGAL, .i = .{ .R = .{} } },
        },
        .{
            .input = 0b000000_00001_00010_00100_00000_101111,
            .expect = .{ .op = mn.ILLEGAL, .i = .{ .R = .{} } },
        },
    };

    try iterate_testcases(&testcases);
}

test "bxxxx (branch)" {
    const testcases = [_]TC{
        .{
            .input = 0b000001_00001_00000_01000_00010_010001,
            .expect = .{ .op = mn.BLTZ, .i = .{ .I = .{ .rs = 1, .imm = 0b01000_00010_010001 } } },
        },
        .{
            .input = 0b000001_00001_00001_01000_00010_010001,
            .expect = .{ .op = mn.BGEZ, .i = .{ .I = .{ .rs = 1, .rt = 1, .imm = 0b01000_00010_010001 } } },
        },
        .{
            .input = 0b000001_00001_10000_01000_00010_010001,
            .expect = .{ .op = mn.BLTZAL, .i = .{ .I = .{ .rs = 1, .rt = 0b10000, .imm = 0b01000_00010_010001 } } },
        },
        .{
            .input = 0b000001_00001_10001_01000_00010_010001,
            .expect = .{ .op = mn.BGEZAL, .i = .{ .I = .{ .rs = 1, .rt = 0b10001, .imm = 0b01000_00010_010001 } } },
        },

        // some undocumented ones
        .{
            .input = 0b000001_00001_10100_01000_00010_010001,
            .expect = .{ .op = mn.BLTZ, .i = .{ .I = .{ .rs = 1, .rt = 0b10100, .imm = 0b01000_00010_010001 } } },
        },
        .{
            .input = 0b000001_00001_10101_01000_00010_010001,
            .expect = .{ .op = mn.BGEZ, .i = .{ .I = .{ .rs = 1, .rt = 0b10101, .imm = 0b01000_00010_010001 } } },
        },
    };

    try iterate_testcases(&testcases);
}

test "j/jal" {
    const testcases = [_]TC{
        .{
            .input = 0b000010_11000_00000_00000_00000_010001,
            .expect = .{ .op = mn.J, .i = .{ .J = .{ .target = 0b11000_00000_00000_00000_010001 } } },
        },
        .{
            .input = 0b000011_11000_00000_00000_00000_010001,
            .expect = .{ .op = mn.JAL, .i = .{ .J = .{ .target = 0b11000_00000_00000_00000_010001 } } },
        },
    };

    try iterate_testcases(&testcases);
}

test "beq/bne" {
    const testcases = [_]TC{
        .{
            .input = 0b000100_00001_00010_11000_00000_010001,
            .expect = .{ .op = mn.BEQ, .i = .{ .I = .{ .rs = 1, .rt = 2, .imm = 0b11000_00000_010001 } } },
        },
        .{
            .input = 0b000101_00001_00010_11000_00000_010001,
            .expect = .{ .op = mn.BNE, .i = .{ .I = .{ .rs = 1, .rt = 2, .imm = 0b11000_00000_010001 } } },
        },
    };

    try iterate_testcases(&testcases);
}

test "blez/bgtz" {
    const testcases = [_]TC{
        .{
            .input = 0b000110_00001_00000_11000_00000_010001,
            .expect = .{ .op = mn.BLEZ, .i = .{ .I = .{ .rs = 1, .imm = 0b11000_00000_010001 } } },
        },
        .{
            .input = 0b000111_00001_00000_11000_00000_010001,
            .expect = .{ .op = mn.BGTZ, .i = .{ .I = .{ .rs = 1, .imm = 0b11000_00000_010001 } } },
        },
    };

    try iterate_testcases(&testcases);
}

test "alu-imm" {
    const testcases = [_]TC{
        .{
            .input = 0b001000_00001_00010_11000_00000_010001,
            .expect = .{ .op = mn.ADDI, .i = .{ .I = .{ .rs = 1, .rt = 2, .imm = 0b11000_00000_010001 } } },
        },
        .{
            .input = 0b001001_00001_00010_11000_00000_010001,
            .expect = .{ .op = mn.ADDIU, .i = .{ .I = .{ .rs = 1, .rt = 2, .imm = 0b11000_00000_010001 } } },
        },
        .{
            .input = 0b001010_00001_00010_11000_00000_010001,
            .expect = .{ .op = mn.SLTI, .i = .{ .I = .{ .rs = 1, .rt = 2, .imm = 0b11000_00000_010001 } } },
        },
        .{
            .input = 0b001011_00001_00010_11000_00000_010001,
            .expect = .{ .op = mn.SLTIU, .i = .{ .I = .{ .rs = 1, .rt = 2, .imm = 0b11000_00000_010001 } } },
        },
        .{
            .input = 0b001100_00001_00010_11000_00000_010001,
            .expect = .{ .op = mn.ANDI, .i = .{ .I = .{ .rs = 1, .rt = 2, .imm = 0b11000_00000_010001 } } },
        },
        .{
            .input = 0b001101_00001_00010_11000_00000_010001,
            .expect = .{ .op = mn.ORI, .i = .{ .I = .{ .rs = 1, .rt = 2, .imm = 0b11000_00000_010001 } } },
        },
        .{
            .input = 0b001110_00001_00010_11000_00000_010001,
            .expect = .{ .op = mn.XORI, .i = .{ .I = .{ .rs = 1, .rt = 2, .imm = 0b11000_00000_010001 } } },
        },
        .{
            .input = 0b001111_00001_00010_11000_00000_010001,
            .expect = .{ .op = mn.LUI, .i = .{ .I = .{ .rs = 1, .rt = 2, .imm = 0b11000_00000_010001 } } },
        },
    };

    try iterate_testcases(&testcases);
}
