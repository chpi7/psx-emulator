const std = @import("std");
const decoder = @import("decoder.zig");
const op_writer = @import("disasm_op_writer.zig");
const lib_bios = @import("bios.zig");
const lib_cpu = @import("cpu.zig");
const lib_bus = @import("bus.zig");

const log = std.log.scoped(.disasm);

pub fn disassemble_bios() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var bios = try lib_bios.Bios.load("./bios/scph-1002-v20-eu.bin", allocator);

    for (0..lib_bios.Bios.size / 4) |b| {
        const i_raw = bios.read_u32(@as(u30, @truncate(b)) * 4);
        const i, const op = decoder.decode(i_raw);

        const w = std.io.getStdOut().writer();
        op_writer.write_instruction(i, op, &w) catch {
            log.err("io error", .{});
        };
    }
}
