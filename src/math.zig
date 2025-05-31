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

test "sign_ext" {
    try std.testing.expectEqual(0xfffffff9, sign_ext(@as(u4, 0b1001)));
    try std.testing.expectEqual(0x5, sign_ext(@as(u4, 0b0101)));
}

test "zero_ext" {
    try std.testing.expectEqual(0x9, zero_ext(@as(u4, 0b1001)));
    try std.testing.expectEqual(0x5, zero_ext(@as(u4, 0b0101)));
}
