const std = @import("std");

pub const Commit = struct {
    hash: []const u8,
    author: []const u8,
    timestamp: u64,
    message: []const u8,

    pub fn serialize(self: *Commit, writer: std.fs.File.Writer) !void {
        try writer.writeInt(u32, @intCast(self.hash.len), .little);
        try writer.writeAll(self.hash);
        try writer.writeInt(u32, @intCast(self.author.len), .little);
        try writer.writeAll(self.author);
        try writer.writeInt(u64, self.timestamp, .little);
        try writer.writeInt(u32, @intCast(self.message.len), .little);
        try writer.writeAll(self.message);
    }

    pub fn deserialize(reader: std.fs.File.Reader, allocator: std.mem.Allocator) !Commit {
        const hash_len = try reader.readInt(u32, .little);
        const hash = try allocator.alloc(u8, hash_len);
        _ = try reader.readAll(hash);

        const author_len = try reader.readInt(u32, .little);
        const author = try allocator.alloc(u8, author_len);
        _ = try reader.readAll(author);

        const timestamp = try reader.readInt(u64, .little);

        const message_len = try reader.readInt(u32, .little);
        const message = try allocator.alloc(u8, message_len);
        _ = try reader.readAll(message);

        return Commit{
            .hash = hash,
            .author = author,
            .timestamp = timestamp,
            .message = message,
        };
    }
};
