const std = @import("std");

// This contains code from: https://github.com/cryptocode/bithacks

/// Asserts at compile time that `T` is an integer, returns `T`
pub fn require_int(comptime T: type) type {
    comptime std.debug.assert(@typeInfo(T) == .int);
    return T;
}

/// Asserts at compile time that `T` is an unsigned integer, returns `T`
pub fn require_unsigned(comptime T: type) type {
    _ = require_int(T);
    comptime std.debug.assert(@typeInfo(T).int.signedness == .unsigned);
    return T;
}

pub fn zero_ext(v: anytype) u32 {
    const T = @TypeOf(v);
    comptime {
        _ = require_unsigned(@TypeOf(v));
        if (@bitSizeOf(T) >= 32) {
            @compileError("zero_extend only works for types smaller than 32 bits");
        }
    }
    return @as(u32, v);
}

/// This always assumes a unsigned input type. Even if the number is actually interpreted as signed.
/// (e.g. imm offset values for address computations.)
pub fn sign_ext(val: anytype) u32 {
    const T = require_unsigned(@TypeOf(val));
    const signed_type = std.meta.Int(.signed, @typeInfo(T).int.bits);
    const val_as_signed = @as(signed_type, @bitCast(val));
    return @bitCast(@as(i32, @intCast(val_as_signed)));
}

pub inline fn bitmask(comptime T: type, comptime one_bits: u7) T {
    return (1 << one_bits) - 1;
}

/// Enable bits in the range [start, end[. (End exclusive)!
pub inline fn bitmask_rng(comptime T: type, comptime start: u7, comptime end: u7) T {
    comptime if (end < 1 or end <= start) return 0;
    return bitmask(T, end - start) << start;
}

/// Same as bitmask_rng, but using start + count instead.
pub inline fn bitmask_rnc(comptime T: type, comptime start: u7, comptime count: u7) T {
    return bitmask(T, count) << start;
}

test "sign_ext" {
    try std.testing.expectEqual(0xfffffff9, sign_ext(@as(u4, 0b1001)));
    try std.testing.expectEqual(0x5, sign_ext(@as(u4, 0b0101)));
}

test "zero_ext" {
    try std.testing.expectEqual(0x9, zero_ext(@as(u4, 0b1001)));
    try std.testing.expectEqual(0x5, zero_ext(@as(u4, 0b0101)));
}

test "bitmask" {
    try std.testing.expectEqual(0x00ff, bitmask(u16, 8));
    try std.testing.expectEqual(0xff, bitmask(u8, 8));
    try std.testing.expectEqual(0, bitmask(u8, 0));
}

test "bitmask_rng" {
    try std.testing.expectEqual(0, bitmask_rng(u16, 4, 0));
    try std.testing.expectEqual(0, bitmask_rng(u16, 4, 3));
    try std.testing.expectEqual(0, bitmask_rng(u16, 4, 4));
    try std.testing.expectEqual(0x0ff0, bitmask_rng(u16, 4, 12));
}

test "bitmask_rnc" {
    try std.testing.expectEqual(0x0, bitmask_rnc(u16, 4, 0));
    try std.testing.expectEqual(0x0f0, bitmask_rnc(u16, 4, 4));
}
