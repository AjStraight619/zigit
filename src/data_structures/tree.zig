const std = @import("std");

const print = std.debug.print;

pub fn Tree(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        value: T,
        is_file: bool,
        children: ?std.ArrayList(*Self),

        pub fn init(allocator: std.mem.Allocator, value: T, is_file: bool) Self {
            return Self{
                .allocator = allocator,
                .value = value,
                .is_file = is_file,
                .children = null,
            };
        }

        pub fn addChild(self: *Self, child_value: T, is_file: bool) !void {
            if (self.children == null) {
                self.children = std.ArrayList(*Self).init(self.allocator);
            }

            const child = try self.allocator.create(Self);
            child.* = Self.init(self.allocator, child_value, is_file);
            try self.children.?.append(child);
        }

        // Traverse function with a comptime callback
        pub fn traverse(self: *Self, comptime callback: fn (*Self) void) void {
            callback(self);
            if (self.children) |children| {
                for (children.items) |child| {
                    child.traverse(callback);
                }
            }
        }
    };
}

pub fn appendTreeValues(comptime T: type, node: *Tree(T), collector: *std.ArrayList(T)) !void {
    std.debug.print("Type of node: {}\n", .{@TypeOf(node)});
    try collector.append(node.value);
    std.debug.print("node children: {any}\n", .{node.children});

    std.debug.print("node children length: {any}\n", .{node.children.?.items.len});
    if (node.children) |children| {
        for (children.items) |child| {
            std.debug.print("Type of child: {}\n", .{@TypeOf(child)});
            try appendTreeValues(T, child, collector);
        }
    }
}
