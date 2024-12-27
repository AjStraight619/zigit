const std = @import("std");
const print = std.debug.print;

const repository = @import("../repository/repository.zig");
const untrackedFiles = @import("../repository/untracked.zig");
const trackedFiles = @import("../repository/tracked_files.zig");
const utils = @import("../utils/utils.zig");

pub const CommandHandler = struct {
    const Self = @This();

    command: Command,
    allocator: std.mem.Allocator,

    pub const Command = union(enum) {
        Init: []const u8, // init takes 1 arg for path to initialize zigit
        Add: []const []const u8, // add takes a slice of args
        Commit: []const []const u8, // commit takes a slice of args
        Status: void, // status takes no args
        Log: void, // No additional data needed for `log` (FOR NOW)
    };

    pub fn init(command_name: []const u8, command_args: []const []const u8, allocator: std.mem.Allocator) !Self {
        return Self{
            .command = try parseCommand(command_name, command_args),
            .allocator = allocator,
        };
    }

    pub fn execute(self: *Self, command: Command) !void {
        switch (command) {
            .Init => |value| {
                print("Command Init: {s}\n", .{value});
                try repository.initZigGit(self.allocator);
            },
            .Add => |value| {
                const paths = value;
                const zigitPath = try utils.findFirstZigit(".", self.allocator);
                if (zigitPath) |path| {
                    const fullZigitPath = try std.mem.concat(self.allocator, u8, &.{ path, "/.zigit/index.bin" });
                    var tracked = trackedFiles.TrackedFiles.init(self.allocator, fullZigitPath);
                    try tracked.add(paths);
                }
            },
            .Commit => |value| {
                print("Command Commit: {s}\n", .{value});
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
                            print("Key: {s}, Value: {any}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
                        }
                    }

                    // var untracked = untrackedFiles.UntrackedFiles.init(self.allocator);
                    // try untracked.log();
                }
            },
            .Log => {
                print("Command Log\n", .{});
            },
        }
    }

    pub fn getName(self: *Command) []const u8 {
        return switch (self.command_type) {
            .Init => "init",
            .Add => "add",
            .Commit => "commit",
            .Log => "log",
        };
    }

    pub fn parseCommand(name: []const u8, args: []const []const u8) !Command {
        if (std.mem.eql(u8, name, "init")) {
            if (args.len > 1) {
                print("init requires exactly one argument: specify the directory where you want to initialize Zigit.\n", .{});
                return error.InvalidOptions;
            }
            return @unionInit(Command, "Init", args[0]);
        } else if (std.mem.eql(u8, name, "add")) {
            return @unionInit(Command, "Add", args);
        } else if (std.mem.eql(u8, name, "commit")) {
            return @unionInit(Command, "Commit", args);
        } else if (std.mem.eql(u8, name, "log")) {
            return @unionInit(Command, "Log", {});
        } else if (std.mem.eql(u8, name, "status")) {
            return @unionInit(Command, "Status", {});
        }
        return error.InvalidCommand;
    }
};
