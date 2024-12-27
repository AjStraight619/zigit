const std = @import("std");
const print = std.debug.print;

const FileState = enum(u8) {
    Modified,
    Added,
    Unchanged,
    Deleted,
};

pub const TrackedFiles = struct {
    allocator: std.mem.Allocator,
    files: ?std.StringHashMap(FileMetadata),
    path: []const u8,

    const Self = @This();

    const FileMetadata = struct {
        file_name: []const u8,
        state: FileState,
        timestamp: u64,
        checksum: []const u8,
        size: u64,

        pub fn serialize(self: *FileMetadata, writer: std.fs.File.Writer) !void {
            try writer.writeInt(u32, @intCast(self.file_name.len), .little);
            try writer.writeAll(self.file_name);
            try writer.writeInt(u8, @intFromEnum(self.state), .little);
            try writer.writeInt(u64, self.timestamp, .little);
            try writer.writeInt(u32, @intCast(self.checksum.len), .little);
            try writer.writeAll(self.checksum);
            try writer.writeInt(u64, self.size, .little);
        }

        pub fn deserialize(reader: std.fs.File.Reader, allocator: std.mem.Allocator) !FileMetadata {
            const file_name_len = try reader.readInt(u32, .little);
            const file_name = try allocator.alloc(u8, file_name_len);
            _ = try reader.readAll(file_name);
            const raw_state = try reader.readInt(u8, .little);
            const state: FileState = @enumFromInt(raw_state);
            const timestamp = try reader.readInt(u64, .little);
            const checksum_len = try reader.readInt(u32, .little);
            const checksum = try allocator.alloc(u8, checksum_len);
            _ = try reader.readAll(checksum);
            const size = try reader.readInt(u64, .little);

            return FileMetadata{
                .file_name = file_name,
                .state = state,
                .timestamp = timestamp,
                .checksum = checksum,
                .size = size,
            };
        }
    };

    pub fn init(allocator: std.mem.Allocator, path: []const u8) Self {
        return Self{
            .allocator = allocator,
            .files = std.StringHashMap(FileMetadata).init(allocator),
            .path = path,
        };
    }

    pub fn load(self: *TrackedFiles) !void {
        const cwd = std.fs.cwd();
        const file = cwd.openFile(self.path, .{ .mode = .read }) catch |err| switch (err) {
            error.FileNotFound => return, // No existing index file
            else => return err,
        };
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var buf: [1024]u8 = undefined;
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            // do something with line...
            print("Line: {any}", .{line});
        }
    }

    pub fn save(self: *TrackedFiles) !void {
        const cwd = std.fs.cwd();
        var file = try cwd.createFile(self.path, .{});
        defer file.close();

        if (self.files) |files| {
            var it = files.iterator();
            while (try it.next()) |entry| {
                try entry.value.serialize(file.writer());
            }
        }
    }
};

test "serialize and deserialize file metadata" {
    const allocator = std.testing.allocator;

    std.debug.print("Starting test: serialize and deserialize file metadata\n", .{});

    var metadata = TrackedFiles.FileMetadata{
        .file_name = "example.txt",
        .state = .Added,
        .timestamp = 1679856000,
        .checksum = "abc123",
        .size = 1024,
    };

    std.debug.print("Original metadata:\n", .{});
    std.debug.print("  file_name: {s}\n", .{metadata.file_name});
    std.debug.print("  state: {any}\n", .{@tagName(metadata.state)});
    std.debug.print("  timestamp: {any}\n", .{metadata.timestamp});
    std.debug.print("  checksum: {s}\n", .{metadata.checksum});
    std.debug.print("  size: {d}\n", .{metadata.size});

    // Serialize to a file
    var file = try std.fs.cwd().createFile("test_metadata.bin", .{});
    defer file.close();
    try metadata.serialize(file.writer());

    std.debug.print("Metadata serialized successfully.\n", .{});

    // Deserialize from the file
    var read_file = try std.fs.cwd().openFile("test_metadata.bin", .{});
    defer read_file.close();
    const deserialized = try TrackedFiles.FileMetadata.deserialize(read_file.reader(), allocator);

    std.debug.print("Deserialized metadata:\n", .{});
    std.debug.print("  file_name: {s}\n", .{deserialized.file_name});
    std.debug.print("  state: {any}\n", .{@tagName(deserialized.state)});
    std.debug.print("  timestamp: {any}\n", .{deserialized.timestamp});
    std.debug.print("  checksum: {s}\n", .{deserialized.checksum});
    std.debug.print("  size: {d}\n", .{deserialized.size});

    // Assertions
    try std.testing.expectEqualStrings(metadata.file_name, deserialized.file_name);
    try std.testing.expectEqual(metadata.state, deserialized.state);
    try std.testing.expectEqual(metadata.timestamp, deserialized.timestamp);
    try std.testing.expectEqualStrings(metadata.checksum, deserialized.checksum);
    try std.testing.expectEqual(metadata.size, deserialized.size);

    allocator.free(deserialized.file_name);
    allocator.free(deserialized.checksum);

    std.debug.print("Test passed: serialize and deserialize file metadata\n", .{});
}

// test "serialize deserialize" {
//     var file = try std.fs.cwd().openFile("test_metadata.bin", .{});
//     defer file.close();
//
//     const allocator = std.testing.allocator;
//
//     const metadata = TrackedFiles.FileMetadata{
//         .file_name = "example.txt",
//         .state = .Modified,
//         .timestamp = 1679856000,
//         .checksum = "abc123",
//         .size = 1024,
//     };
//
//     const writer = file.writer();
//
//     try TrackedFiles.serialize(writer);
// }
