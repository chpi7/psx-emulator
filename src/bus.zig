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
/// KSEG2 -> only IO (Cache Control)
const MM = struct {
    /// Target region of the memory map.
    /// IO_CACHE is KSEG2 only.
    pub const Region = enum { RAM, EX1, SCR, IO, EX2, EX3, BIOS, IO_CACHE };

    /// Segment of the memory map.
    pub const Segment = enum { KUSEG, KSEG0, KSEG1, KSEG2 };

    /// Entry in the memory map.
    pub const Entry = struct {
        start: u32 = 0,
        size: u32 = 0,
        reg: Region,
        seg: Segment,

        pub fn end(comptime self: @This()) u32 {
            return self.start + (self.size - 1);
        }
    };

    // KSEG1 Mappings:
    pub const ram: Entry = .{ .reg = .RAM, .seg = .KSEG1, .start = 0xa0000000, .size = 2048 * 1024 };
    pub const ex1: Entry = .{ .reg = .EX1, .seg = .KSEG1, .start = 0xbf000000, .size = 8192 * 1024 };
    pub const io: Entry = .{ .reg = .IO, .seg = .KSEG1, .start = 0xbf801000, .size = 8 * 1024 };
    pub const bios: Entry = .{ .reg = .BIOS, .seg = .KSEG1, .start = 0xbfc00000, .size = 512 * 1024 };
};

inline fn bitmask(comptime n: u32) u32 {
    return (1 << n) - 1;
}

inline fn is_aligned_log2(addr: u32, comptime alignment: u32) bool {
    return (addr & bitmask(alignment)) == 0;
}

pub const Exception = enum { Address };

pub const Bus = struct {
    bios: *bios.Bios,

    pub fn read32(self: *@This(), a: u32) u32 {
        if (!is_aligned_log2(a, 2)) {
            log.warn("unaligned read32 {x}", .{a});
            self.signal_exception(.Address);
        }

        var res: u32 = 0;
        switch (a) {
            MM.bios.start...MM.bios.end() => {
                res = self.bios.read_u32(a - MM.bios.start);
            },
            else => {
                log.warn("unmapped memory (read, address = {x})", .{a});
                res = 0;
            },
        }

        log.debug("read [{x}] -> {x}", .{ a, res });

        return res;
    }

    pub fn write32(self: *@This(), a: u32, v: u32) void {
        if (!is_aligned_log2(a, 2)) {
            log.warn("unaligned write32 {x}", .{a});
            self.signal_exception(.Address);
        }

        log.debug("write [{x}] = {x}", .{ a, v });
        switch (a) {
            MM.bios.start...MM.bios.end() => {
                // BIOS ROM is read only: (https://github.com/simias/psx-hardware-tests/blob/master/tests/bios_write/main.s)
                // no exception, no errors generated
            },
            else => {
                log.warn("unmapped memory (write, address = {x})", .{a});
            },
        }
    }

    /// This should roughly do what the pseudo function "SignalException" does in
    /// https://www.cs.cmu.edu/afs/cs/academic/class/15740-f97/public/doc/mips-isa.pdf.
    fn signal_exception(self: *@This(), e: Exception) void {
        _ = self;
        _ = e;
        // TODO
    }
};

test "bitmask" {
    try std.testing.expectEqual(0b0, bitmask(0));
    try std.testing.expectEqual(0b1, bitmask(1));
    try std.testing.expectEqual(0b1111, bitmask(4));
    try std.testing.expectEqual(0b11111111_11111111_11111111_11111111, bitmask(32));
}

test "is_aligned_log2" {
    // everything is aligned to 1
    try std.testing.expect(is_aligned_log2(1, 0));
    try std.testing.expect(is_aligned_log2(2, 0));
    try std.testing.expect(is_aligned_log2(3, 0));

    // aligned to 2
    try std.testing.expect(!is_aligned_log2(1, 1));
    try std.testing.expect(is_aligned_log2(2, 1));
    try std.testing.expect(!is_aligned_log2(3, 1));
    try std.testing.expect(is_aligned_log2(4, 1));

    // aligned to 4
    try std.testing.expect(is_aligned_log2(4, 2));
    try std.testing.expect(is_aligned_log2(8, 2));
    try std.testing.expect(!is_aligned_log2(10, 2));
}
