const std = @import("std");
const print = std.debug.print;
const repository = @import("../repository/repository.zig");
const trackedFiles = @import("../repository/tracked_files.zig");
const utils = @import("../repository/utils.zig");

pub const CommandHandler = struct {
    allocator: std.mem.Allocator,

    pub fn execute(self: *CommandHandler, command: anytype) !void {
        switch (command) {
            .Init => |value| {
                print("Initializing repository at: {s}\n", .{value});
                try repository.initZigGit(self.allocator);
            },
            .Add => |filePaths| {
                const zigitPath = try utils.findFirstZigit(".", self.allocator);
                if (zigitPath) |path| {
                    const fullZigitPath = try std.mem.concat(self.allocator, u8, &.{ path, "/.zigit/index.bin" });
                    var tracked = trackedFiles.TrackedFiles.init(self.allocator, fullZigitPath);
                    try tracked.add(filePaths);
                }
            },
            .Commit => |value| {
                print("Commit command: {s}\n", .{value});
            },
            .Status => {
                const zigitPath = try utils.findFirstZigit(".", self.allocator);
                if (zigitPath) |path| {
                    const fullZigitPath = try std.mem.concat(self.allocator, u8, &.{ path, "/test_metadata.bin" });
                    var tracked = trackedFiles.TrackedFiles.init(self.allocator, fullZigitPath);

                    try tracked.load();

                    if (tracked.files) |files| {
                        var it = files.iterator();
                        while (it.next()) |entry| {
                            print("File: {s}, Metadata: {any}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
                        }
                    }
                }
            },
            .Log => {
                print("Log command executed.\n", .{});
            },
        }
    }
};
