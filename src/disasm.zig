const std = @import("std");
const decoder = @import("decoder.zig");
const op_writer = @import("disasm_op_writer.zig");
const lib_bios = @import("bios.zig");
const lib_cpu = @import("cpu.zig");
const lib_bus = @import("bus.zig");

const ascii = std.ascii;

const log = std.log.scoped(.disasm);

inline fn to_printable(c: u8) u8 {
    return if (ascii.isPrint(c)) c else '.';
}

pub fn disassemble_bios() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var bios = try lib_bios.Bios.load("./bios/scph-1002-v20-eu.bin", allocator);

    for (0..lib_bios.Bios.size / 4) |b| {
        const i_raw = bios.read_u32(@as(u30, @truncate(b)) * 4);
        const i, const op = decoder.decode(i_raw);

        const w = std.io.getStdOut().writer();

        // offset in file
        try w.print("{x:08}   ", .{4 * b});

        // offset in memory in KUSEG
        // try w.print("{x:08}   ", .{4 * b + 0x1fc00000});

        // offset in memory in KUSEG0
        // try w.print("{x:08}   ", .{4 * b + 0x9fc00000});

        // offset in memory in KUSEG1
        try w.print("{x:08}   ", .{4 * b + 0xbfc00000});

        try w.print("{x:08}   ", .{i_raw});

        const as_str: [4]u8 = @bitCast(i_raw);
        try w.print("{c}{c}{c}{c}   ", .{
            to_printable(as_str[0]),
            to_printable(as_str[1]),
            to_printable(as_str[2]),
            to_printable(as_str[3]),
        });

        try w.print("  ", .{});

        op_writer.write_instruction(i, op, &w, true) catch {
            log.err("io error", .{});
        };
    }
}
