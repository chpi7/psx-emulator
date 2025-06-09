const decoder = @import("decoder.zig");
const std = @import("std");

const I = decoder.I;
const Op = decoder.opcodes.op;

// 7 == strlen("ILLEGAL")
const OP_FMT = "{s: <7}   ";

fn write_imm26(i: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "{x}", .{ @tagName(op), i.J.target });
}

fn write_op_rd(i: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "$r{d}", .{ @tagName(op), i.R.rd });
}

fn write_op_rd_rs(i: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "$r{d}, $r{d}", .{ @tagName(op), i.R.rd, i.R.rs });
}

fn write_op_rd_rs_rt(i: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "$r{d}, $r{d}, $r{d}", .{ @tagName(op), i.R.rd, i.R.rs, i.R.rt });
}

fn write_op_rd_rt_re(i: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "$r{d}, $r{d}, $r{d}", .{ @tagName(op), i.R.rd, i.R.rt, i.R.re });
}

fn write_op_rd_rt_rs(i: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "$r{d}, $r{d}, $r{d}", .{ @tagName(op), i.R.rd, i.R.rt, i.R.rs });
}

fn write_op_rs(i: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "$r{d}", .{ @tagName(op), i.R.rs });
}

fn write_op_rs_imm(i: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "$r{d}, {x}", .{ @tagName(op), i.I.rs, i.I.imm });
}

fn write_op_rs_rt(i: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "$r{d}, $r{d}", .{ @tagName(op), i.R.rs, i.R.rt });
}

fn write_op_rt_imm(i: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "$r{d}, {x}", .{ @tagName(op), i.I.rt, i.I.imm });
}

fn write_op_rs_rt_imm(i: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "$r{d}, $r{d}, {x}", .{ @tagName(op), i.I.rs, i.I.rt, i.I.imm });
}

fn write_op_rt_offset_base(i: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "$r{d}, {x}, $r{d}", .{ @tagName(op), i.I.rt, i.I.imm, i.I.rs });
}

fn write_op_rt_rs_imm(i: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "$r{d}, $r{d}, {x}", .{ @tagName(op), i.I.rt, i.I.rs, i.I.imm });
}

fn write_op_sys_brk(i: I, op: Op, w: anytype) !void {
    // bits 6 - 25 are treated as a "comment"
    const comment: u20 = @truncate(@as(u32, @bitCast(i.R)) >> 6);
    try w.print(OP_FMT ++ "{x}", .{ @tagName(op), comment });
}

fn write_op_rt_fs(i: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "$r{d}, <fs>", .{ @tagName(op), i.R.rt });
}

fn write_op_cc_offset_fp(_: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "<None>, <offset>, <fp>", .{@tagName(op)});
}

fn write_unknown(_: I, op: Op, w: anytype) !void {
    try w.print(OP_FMT ++ "<unknown>", .{@tagName(op)});
}

pub fn write_instruction(i: I, op: Op, w: anytype) !void {
    _ = try switch (op) {
        .COPz => write_imm26(i, op, w),
        .J => {
            try write_imm26(i, op, w);
            const target_general = @as(u28, i.J.target) << 2;
            try w.print("     --> {x:08}", .{target_general});
        },
        .JAL => write_imm26(i, op, w),
        .JR => write_op_rs(i, op, w),
        .LB => write_op_rt_offset_base(i, op, w),
        .LBU => write_op_rt_offset_base(i, op, w),
        .LH => write_op_rt_offset_base(i, op, w),
        .LHU => write_op_rt_offset_base(i, op, w),
        .LW => write_op_rt_offset_base(i, op, w),
        .LWCz => write_op_rt_offset_base(i, op, w),
        .LWL => write_op_rt_offset_base(i, op, w),
        .LWR => write_op_rt_offset_base(i, op, w),
        .SB => write_op_rt_offset_base(i, op, w),
        .SH => write_op_rt_offset_base(i, op, w),
        .SW => write_op_rt_offset_base(i, op, w),
        .SWCz => write_op_rt_offset_base(i, op, w),
        .SWL => write_op_rt_offset_base(i, op, w),
        .SWR => write_op_rt_offset_base(i, op, w),
        .LUI => write_op_rt_imm(i, op, w),
        .MFHI => write_op_rd(i, op, w),
        .MFLO => write_op_rd(i, op, w),
        .MTHI => write_op_rs(i, op, w),
        .MTLO => write_op_rs(i, op, w),
        .MULT => write_op_rs_rt(i, op, w),
        .MULTU => write_op_rs_rt(i, op, w),
        .DIV => write_op_rs_rt(i, op, w),
        .DIVU => write_op_rs_rt(i, op, w),
        .ADD => write_op_rd_rs_rt(i, op, w),
        .ADDU => write_op_rd_rs_rt(i, op, w),
        .AND => write_op_rd_rs_rt(i, op, w),
        .NOR => write_op_rd_rs_rt(i, op, w),
        .OR => write_op_rd_rs_rt(i, op, w),
        .SLT => write_op_rd_rs_rt(i, op, w),
        .SLTU => write_op_rd_rs_rt(i, op, w),
        .SUB => write_op_rd_rs_rt(i, op, w),
        .SUBU => write_op_rd_rs_rt(i, op, w),
        .XOR => write_op_rd_rs_rt(i, op, w),
        .ADDI => write_op_rt_rs_imm(i, op, w),
        .ADDIU => write_op_rt_rs_imm(i, op, w),
        .ANDI => write_op_rt_rs_imm(i, op, w),
        .ORI => write_op_rt_rs_imm(i, op, w),
        .SLTI => write_op_rt_rs_imm(i, op, w),
        .SLTIU => write_op_rt_rs_imm(i, op, w),
        .XORI => write_op_rt_rs_imm(i, op, w),
        .SLL => write_op_rd_rt_re(i, op, w),
        .SRA => write_op_rd_rt_re(i, op, w),
        .SRL => write_op_rd_rt_re(i, op, w),
        .JALR => write_op_rd_rs(i, op, w),
        .SLLV => write_op_rd_rt_rs(i, op, w),
        .SRAV => write_op_rd_rt_rs(i, op, w),
        .SRLV => write_op_rd_rt_rs(i, op, w),
        .BREAK => write_op_sys_brk(i, op, w),
        .SYSCALL => write_op_sys_brk(i, op, w),
        .BEQ => write_op_rs_rt_imm(i, op, w),
        .BNE => write_op_rs_rt_imm(i, op, w),
        .BGEZ => write_op_rs_imm(i, op, w),
        .BGEZAL => write_op_rs_imm(i, op, w),
        .BGTZ => write_op_rs_imm(i, op, w),
        .BLEZ => write_op_rs_imm(i, op, w),
        .BLTZ => write_op_rs_imm(i, op, w),
        .BLTZAL => write_op_rs_imm(i, op, w),
        .CFCz => write_op_rt_fs(i, op, w),
        .CTCz => write_op_rt_fs(i, op, w),
        .MFCz => write_op_rt_fs(i, op, w),
        .MTCz => write_op_rt_fs(i, op, w),
        .BCzT => write_op_cc_offset_fp(i, op, w),
        .BCzF => write_op_cc_offset_fp(i, op, w),
        else => write_unknown(i, op, w),
    };
    try w.print("\n", .{});
}
