const std = @import("std");

pub const Command = union(enum) {
    Init: []const u8, // `init` takes a single argument (e.g., path)
    Add: []const []const u8, // `add` takes multiple file paths
    Commit: []const []const u8, // `commit` takes commit message and options
    Status: void, // `status` requires no arguments
    Log: void, // `log` requires no arguments
};

pub fn parse(name: []const u8, args: []const []const u8) !Command {
    if (std.mem.eql(u8, name, "init")) {
        if (args.len != 1) {
            return error.InvalidOptions; // Validate argument count
        }
        return @unionInit(Command, "Init", args[0]);
    } else if (std.mem.eql(u8, name, "add")) {
        return @unionInit(Command, "Add", args);
    } else if (std.mem.eql(u8, name, "commit")) {
        return @unionInit(Command, "Commit", args);
    } else if (std.mem.eql(u8, name, "status")) {
        return @unionInit(Command, "Status", {});
    } else if (std.mem.eql(u8, name, "log")) {
        return @unionInit(Command, "Log", {});
    } else {
        return error.InvalidCommand; // Return error for unrecognized commands
    }
}
