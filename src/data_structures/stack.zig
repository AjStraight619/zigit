const std = @import("std");

pub fn Stack(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: *std.mem.Allocator,
        capacity: usize,
        items: []T,
        count: usize,

        pub fn init(allocator: *std.mem.Allocator, capacity: usize) !Self {
            return Self{ .allocator = allocator, .capacity = capacity, .items = try allocator.alloc(T, capacity), .count = 0 };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.items);
            self.items = @as([]T, &[_]T{});
            self.capacity = 0;
            self.count = 0;
        }

        pub fn getLength(self: Self) usize {
            return self.items.len;
        }

        pub fn push(self: *Self, value: T) !void {
            if (self.count >= self.capacity) {
                self.items = try self.allocator.realloc(self.items, self.capacity * 2);
                self.capacity *= 2;
            }
            self.items[self.count] = value;
            self.count += 1;
        }
        pub fn pop(self: *Self) ?T {
            if (self.count == 0) return std.debug.panic("Stack underflow", .{});
            // const ptr_to_item = &self.items[self.count];
            // self.allocator.destroy(ptr_to_item);
            self.count -= 1;
            return self.items[self.count];
        }

        pub fn print(self: *Self) void {
            for (0..self.count) |i| {
                std.debug.print("This is item: {} at index: {}\n", .{ self.items[i], i });
            }
        }
    };
}
