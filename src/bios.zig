const std = @import("std");

fn get_absolute_path(filename: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd);

    return try std.fs.path.resolve(allocator, &.{ cwd, filename });
}

pub const Bios = struct {
    pub const size = 512 * 1024; // bios is always exactly 512K

    data: [Bios.size]u8 align(@sizeOf(u32)) = .{0} ** (Bios.size),

    pub fn load(filename: []const u8, allocator: std.mem.Allocator) !Bios {
        const abs_input = get_absolute_path(filename, allocator) catch |err| {
            std.debug.print("Error getting absolute path. ({})", .{err});
            return err;
        };
        defer allocator.free(abs_input);

        const file = std.fs.openFileAbsolute(abs_input, .{}) catch |err| {
            std.debug.print("Error opening input file: {}", .{err});
            return err;
        };
        defer file.close();

        const file_size = try file.getEndPos();
        if (file_size != Bios.size) {
            std.log.err("Bios file {s} not of expected size (found = {}, expected = {})", .{ filename, file_size, Bios.size });
        }

        var cartridge = Bios{};

        const actually_read = try file.readAll(&cartridge.data);
        if (actually_read != file_size) {
            std.log.err("Bytes read vs file size mismatch! (expected {}, found {})", .{ file_size, actually_read });
        }

        std.log.debug("BIOS file {s} loaded (size = {}KB)", .{ filename, file_size / 1024 });

        return cartridge;
    }

    pub fn read_u32(self: *Bios, offset: usize) u32 {
        // const u32_ptr: *u32 = @ptrCast(&self.data[offset]);
        return std.mem.bytesAsSlice(u32, self.data[offset..])[0];
    }
};
