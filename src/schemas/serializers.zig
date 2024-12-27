const std = @import("std");
const Schema = @import("./field.zig").Schema;

pub fn serialize(comptime schema: Schema, instance: anytype, writer: std.fs.File.Writer) !void {
    for (schema.fields) |field| {
        switch (field.field_type) {
            .Int => {
                const value = @field(instance, field.name);
                try writer.writeInt(u32, value, .little);
            },
            .String => {
                const str_value = @field(instance, field.name);
                try writer.writeInt(u32, @intCast(str_value.len), .little);
                try writer.writeAll(str_value);
            },
            .U64 => {
                const value = @field(instance, field.name);
                try writer.writeInt(u64, value, .little);
            },
            else => {
                // Handle other cases as needed
            },
        }
    }
}

pub fn deserialize(comptime T: Schema, reader: std.fs.File.Reader, allocator: std.mem.Allocator) !T {
    var instance: T = undefined;
    for (T.fields) |field| {
        switch (field.field_type) {
            .Int => {
                const value = try reader.readInt(u32, .little);
                @field(instance, field.name) = value;
            },
            .String => {
                const str_len = try reader.readInt(u32, .little);
                const str_value = try allocator.alloc(u8, str_len);
                _ = try reader.readAll(str_value);
                @field(instance, field.name) = str_value;
            },
            .U64 => {
                const value = try reader.readInt(u64, .little);
                @field(instance, field.name) = value;
            },
            else => {},
        }
    }
    return instance;
}
