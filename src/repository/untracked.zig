const std = @import("std");
const print = std.debug.print;
const utils = @import("../utils/utils.zig");

pub const UntrackedFiles = struct {
    allocator: std.mem.Allocator,
    files: ?std.ArrayList([]const u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .files = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn add(self: *UntrackedFiles, file_name: []const u8) !void {
        if (self.files) |files| {
            try files.append(file_name);
        }
    }

    pub fn log(self: *Self) !void {
        const path = try utils.findFirstZigit(".", self.allocator);

        if (path) |zigit| {
            print("start dir: {s}\n\n", .{zigit});
            const cwd = std.fs.cwd();
            var dir = try cwd.openDir(".", .{
                .iterate = true,
                // .access_sub_paths = true,
            });
            var it = dir.iterate();
            defer dir.close();

            while (try it.next()) |entry| {
                // if (!utils.shouldProcess(entry.name)) {
                //     continue;
                // }
                switch (entry.kind) {
                    .directory => print("directory: {s}/\n", .{entry.name}),
                    .file => print("file: {s}\n", .{entry.name}),
                    else => print("file type not supported: {s}\n", .{entry.name}),
                }
            }
        }

        const stdout_file = std.io.getStdOut().writer();
        var bw = std.io.bufferedWriter(stdout_file);
        const stdout = bw.writer();
        try stdout.print("Run `zig build test` to run the tests.\n", .{});

        try bw.flush();
    }

    // pub fn serialize(self: *UntrackedFiles, writer: std.fs.File.Writer) !void {
    //     if (self.files) |files| {
    //         for (files.items) |file_name| {
    //             try writer.writeInt(u32, @intCast(file_name.len), .little);
    //             try writer.writeAll(file_name);
    //         }
    //     }
    // }

    // pub fn deserialize(reader: std.fs.File.Reader, allocator: std.mem.Allocator) !UntrackedFiles {
    //     var files = try std.ArrayList([]const u8).init(allocator);
    //     while (reader.bytesLeft() > 0) {
    //         const file_name_len = try reader.readInt(u32, .little);
    //         const file_name = try allocator.alloc(u8, file_name_len);
    //         _ = try reader.readAll(file_name);
    //         try files.append(file_name);
    //     }
    //
    //     return UntrackedFiles{
    //         .allocator = allocator,
    //         .files = files,
    //     };
    // }
};
