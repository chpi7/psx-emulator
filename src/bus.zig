const std = @import("std");
const bios = @import("bios.zig");

const log = std.log.scoped(.bus);

/// KUSEG     KSEG0     KSEG1
/// 00000000h 80000000h A0000000h  2048K  Main RAM (first 64K reserved for BIOS)
/// 1F000000h 9F000000h BF000000h  8192K  Expansion Region 1 (ROM/RAM)
/// 1F800000h 9F800000h    --      1K     Scratchpad (D-Cache used as Fast RAM)
/// 1F801000h 9F801000h BF801000h  8K     I/O Ports
/// 1F802000h 9F802000h BF802000h  8K     Expansion Region 2 (I/O Ports)
/// 1FA00000h 9FA00000h BFA00000h  2048K  Expansion Region 3 (whatever purpose)
/// 1FC00000h 9FC00000h BFC00000h  512K   BIOS ROM (Kernel) (4096K max)
///
/// KSEG2 only: FFFE0000h, size 0.5K
///
/// KUSEG -> user
/// KSEG0 -> cached mirror of KSEG1
/// KSEG1 -> uncached "normal" memory
/// KSEG2 -> contains cache control and io ports
const MM = struct {
    pub const Entry = struct {
        start: u32 = 0,
        size: u32 = 0,
        name: []const u8 = "",
    };

    // KSEG1 Mappings:
    pub const ram: Entry = .{ .start = 0xa0000000, .size = 2048 * 1024, .name = "RAM" };
    pub const exp1: Entry = .{ .start = 0xbf000000, .size = 8192 * 1024, .name = "Expansion Region 1" };
    pub const io: Entry = .{ .start = 0xbf801000, .size = 8 * 1024, .name = "Expansion Region 2" };
    pub const exp2: Entry = .{ .start = 0xbf802000, .size = 8 * 1024, .name = "Expansion Region 2" };
    pub const exp3: Entry = .{ .start = 0xbfa00000, .size = 2048 * 1024, .name = "Expansion Region 3" };
    pub const bios: Entry = .{ .start = 0xbfc00000, .size = 512 * 1024, .name = "BIOS ROM" };
};

pub const Bus = struct {
    bios: *bios.Bios,

    pub fn read32(self: *@This(), a: u32) u32 {
        log.debug("read {x}", .{a});
        switch (a) {
            MM.bios.start...(MM.bios.start + MM.bios.size - 1) => {
                return self.bios.read_u32(a - MM.bios.start);
            },
            else => {
                log.warn("unmapped memory (read, address = {x})", .{a});
                return 0;
            },
        }
    }

    pub fn write32(_: *@This(), a: u32, v: u32) void {
        if ((a & 0b11) != 0) {
            // not aligned to 4 bytes -> error
            // TODO: Address Exception
        }

        log.debug("write {x} := {x}", .{ a, v });
        switch (a) {
            MM.bios.start...(MM.bios.start + MM.bios.size - 1) => {
                // BIOS ROM is read only: (https://github.com/simias/psx-hardware-tests/blob/master/tests/bios_write/main.s)
                // no exception, no errors generated
            },
            else => {
                log.warn("unmapped memory (write, address = {x})", .{a});
            },
        }
    }
};
