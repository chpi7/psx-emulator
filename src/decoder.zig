const std = @import("std");
const opcodes = @import("opcodes.zig");

const log = std.log.scoped(.decoder);

const mn = opcodes.op;
const sop = opcodes.subop;
const pop = opcodes.primary;

/// S is SYSCALL or BREAK
/// Others as per spec
const Type = enum { I, J, R, S };

const I_I = packed struct(u32) {
    imm: u16 = 0,
    rt: u5 = 0,
    rs: u5 = 0,
    op: u6 = 0,
};

const I_J = packed struct(u32) {
    target: u26 = 0,
    op: u6 = 0,
};

const I_R = packed struct(u32) {
    funct: u6 = 0,
    re: u5 = 0,
    rd: u5 = 0,
    rt: u5 = 0,
    rs: u5 = 0,
    op: u6 = 0,
};

const I_S = packed struct(u32) {
    funct: u6 = 0,
    comment: u20 = 0,
    op: u6 = 0,
};

pub const I = union(Type) {
    I: I_I,
    J: I_J,
    R: I_R,
    S: I_S,
};

fn get_type(i: I, op: mn) Type {
    switch (@as(opcodes.primary, @enumFromInt(i.R.op))) {
        pop.SPECIAL => switch (i.R.funct) {
            @intFromEnum(sop.BREAK), @intFromEnum(sop.SYSCALL) => return Type.S,
            else => return Type.R,
        },
        pop.BcondZ => return Type.I,
        pop.JAL, pop.J => return Type.J,
        else => {},
    }

    // If it isn't coprocessor now, it is Type I for sure:
    // (Coprocessor instruction have bit 5 set.)
    if (0b010000 & i.R.op == 0) {
        return Type.I;
    }

    // For subprocessor ones, look at the final opcode / mnemonic instead:
    return switch (op) {
        mn.MFC0, mn.MFC1, mn.MFC2, mn.MFC3 => Type.R,
        mn.CFC0, mn.CFC1, mn.CFC2, mn.CFC3 => Type.R,
        mn.MTC0, mn.MTC1, mn.MTC2, mn.MTC3 => Type.R,
        mn.CTC0, mn.CTC1, mn.CTC2, mn.CTC3 => Type.R,
        mn.LWC0, mn.LWC1, mn.LWC2, mn.LWC3 => Type.R,
        mn.SWC0, mn.SWC1, mn.SWC2, mn.SWC3 => Type.R,
        mn.BC0F, mn.BC1F, mn.BC2F, mn.BC3F => Type.I,
        mn.BC0T, mn.BC1T, mn.BC2T, mn.BC3T => Type.I,
        // This isn't fully correct, there is some COPn ones with imm25 encoding. TODO: sort this out later
        else => Type.I,
    };
}

fn get_op_branch(i: I) mn {
    return switch (i.R.rt) {
        0b00000 => mn.BLTZ,
        0b00001 => mn.BGEZ,
        0b10000 => mn.BLTZAL,
        0b10001 => mn.BGEZAL,

        // undocumented duplicates (if bit 17-19 is non-zero)
        0b00010 => mn.BLTZ,
        0b00100 => mn.BLTZ,
        0b00110 => mn.BLTZ,
        0b01000 => mn.BLTZ,
        0b01010 => mn.BLTZ,
        0b01100 => mn.BLTZ,
        0b01110 => mn.BLTZ,

        0b00011 => mn.BGEZ,
        0b00101 => mn.BGEZ,
        0b00111 => mn.BGEZ,
        0b01001 => mn.BGEZ,
        0b01011 => mn.BGEZ,
        0b01101 => mn.BGEZ,
        0b01111 => mn.BGEZ,

        else => mn.ILLEGAL,
    };
}

fn get_op_copz(i: I) mn {
    // last 2 bits in some instructions incode the coprocessor id.
    const nn: u2 = @truncate(i.R.op);

    std.debug.assert(@as(mn, @enumFromInt(@intFromEnum(mn.MFC0) + 1)) == mn.MFC1);
    std.debug.assert(@as(mn, @enumFromInt(@intFromEnum(mn.MFC0) + 2)) == mn.MFC2);
    std.debug.assert(@as(mn, @enumFromInt(@intFromEnum(mn.MFC0) + 3)) == mn.MFC3);

    std.debug.assert(@as(mn, @enumFromInt(@intFromEnum(mn.BC0T) + 2)) == mn.BC1T);
    std.debug.assert(@as(mn, @enumFromInt(@intFromEnum(mn.BC1T) + 2)) == mn.BC2T);
    std.debug.assert(@as(mn, @enumFromInt(@intFromEnum(mn.BC0F) + 2)) == mn.BC1F);
    std.debug.assert(@as(mn, @enumFromInt(@intFromEnum(mn.BC1F) + 2)) == mn.BC2F);

    std.debug.assert((i.R.op & 0b11000) == 0b01000);

    return switch (i.R.rs) {
        0b00000 => @enumFromInt(@intFromEnum(mn.MFC0) + nn),
        0b00010 => @enumFromInt(@intFromEnum(mn.CFC0) + nn),
        0b00100 => @enumFromInt(@intFromEnum(mn.MTC0) + nn),
        0b00110 => @enumFromInt(@intFromEnum(mn.CTC0) + nn),
        0b01000 => switch (i.R.rt) {
            // These are interleaved because of alphanumeric sorting :)
            0 => @enumFromInt(@intFromEnum(mn.BC0F) + 2 * nn),
            1 => @enumFromInt(@intFromEnum(mn.BC0T) + 2 * nn),
            else => mn.ILLEGAL,
        },
        0b10000 => @enumFromInt(@intFromEnum(mn.COP0) + nn),
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
        Type.S => I{ .S = @bitCast(in) },
    };

    return .{ instr, op };
}
