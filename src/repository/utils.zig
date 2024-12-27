const std = @import("std");

pub fn getCwdPath(allocator: std.mem.Allocator) ![]u8 {
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const path = try std.fs.realpath(".", &buf);

    const allocatedPath = try allocator.dupe(u8, path);

    std.debug.print("Path: {s}\n", .{path});
    std.debug.print("Allocated Path: {s}\n", .{allocatedPath});

    return allocatedPath;
}
