const std = @import("std");
const print = std.debug.print;

const utils = @import("../utils/utils.zig");

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
        timestamp: i128,
        checksum: []const u8,
        size: u64,

        pub fn serialize(self: *FileMetadata, writer: std.fs.File.Writer) !void {
            try writer.writeInt(u32, @intCast(self.file_name.len), .little);
            try writer.writeAll(self.file_name);
            try writer.writeInt(u8, @intFromEnum(self.state), .little);
            try writer.writeInt(u64, @intCast(self.timestamp), .little);
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
            const castedTimeStamp: i128 = @intCast(timestamp);
            const checksum_len = try reader.readInt(u32, .little);
            const checksum = try allocator.alloc(u8, checksum_len);
            _ = try reader.readAll(checksum);
            const size = try reader.readInt(u64, .little);

            return FileMetadata{
                .file_name = file_name,
                .state = state,
                .timestamp = castedTimeStamp,
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

        print("Tracked files load path: {s}\n", .{self.path});
        const file = cwd.openFile(self.path, .{ .mode = .read_only }) catch |err| switch (err) {
            error.FileNotFound => return, // No existing index file
            else => return err,
        };
        defer file.close();

        const reader = file.reader();

        // Read the file until EOF and deserialize each metadata entry

        if (self.files) |*files| {
            // Read the file until EOF and deserialize each metadata entry
            while (true) {
                const metadata = FileMetadata.deserialize(reader, self.allocator) catch |err| switch (err) {
                    error.EndOfStream => break, // Exit the loop when EOF is reached
                    else => return err, // Propagate other errors
                };

                // Store the deserialized metadata in the `files` hashmap
                try files.put(metadata.file_name, metadata);
            }
        } else {
            return error.NoFilesHashMap;
        }
    }

    pub fn save(self: *TrackedFiles) !void {
        const cwd = std.fs.cwd();
        var file = try cwd.createFile(self.path, .{});
        defer file.close();

        if (self.files) |files| {
            // Extract keys
            var keys = try self.allocator.alloc([]const u8, files.count());
            defer self.allocator.free(keys);

            var it = files.iterator();
            var i = 0;
            while (try it.next()) |entry| {
                keys[i] = entry.key;
                i += 1;
            }

            // Sort keys in ascending order
            std.sort.block([]const u8, keys, .{}, std.sort.asc([]const u8));

            // Serialize entries in sorted order
            for (keys) |key| {
                const entry = files.get(key) orelse unreachable;
                try entry.serialize(file.writer());
            }
        }
    }

    pub fn add(self: *Self, filePaths: []const []const u8) !void {
        const cwd = std.fs.cwd();

        var file = try cwd.openFile(self.path, .{ .mode = .read_write });

        defer file.close();

        for (filePaths) |filePath| {
            std.debug.print("Walking path: {s}\n", .{filePath});
            const start_path = try self.allocator.dupe(u8, filePath);
            defer self.allocator.free(start_path);
            var dir = try cwd.openDir(start_path, .{ .iterate = true });
            defer dir.close();
            var walker = try dir.walk(self.allocator);
            defer walker.deinit();
            while (try walker.next()) |entry| {

                // Skip unwanted basenames
                if (!utils.shouldProcess(entry.path)) {
                    continue;
                }

                const stat = try cwd.statFile(entry.path);
                const checksum = try calculateChecksum(entry.path, self.allocator);
                defer self.allocator.free(checksum);

                const trackedFile = TrackedFiles.FileMetadata{
                    .file_name = entry.basename,
                    .state = FileState.Added,
                    .timestamp = stat.mtime,
                    .checksum = checksum,
                    .size = stat.size,
                };

                if (self.files) |*files| {
                    try files.put(entry.basename, trackedFile);
                }

                print("Newly tracked file: {s}\n", .{trackedFile.file_name});
            }
        }
    }
};

pub fn calculateChecksum(path: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    var hasher = std.crypto.hash.Blake3.init(.{});
    var reader = file.reader();

    const buffer_size = 4096;
    var buffer = try allocator.alloc(u8, buffer_size);
    defer allocator.free(buffer);

    // Read the file in chunks and update the hash
    while (true) {
        const bytes_read = try reader.read(buffer);
        if (bytes_read == 0) break; // End of file
        hasher.update(buffer[0..bytes_read]);
    }

    // Allocate the result buffer for the hash output
    const hash_size = std.crypto.hash.Blake3.digest_length;
    const hash_result = try allocator.alloc(u8, hash_size);

    // Finalize the hash and store it in the result buffer
    hasher.final(hash_result);

    return hash_result;
}

test "serialize and deserialize file metadata" {
    const allocator = std.testing.allocator;

    const path = try utils.findFirstZigit(".", allocator);
    if (path) |p| {
        defer allocator.free(p);
    }

    std.debug.print("Starting test: serialize and deserialize file metadata\n\n", .{});

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

    std.debug.print("Test passed: serialize and deserialize file metadata\n\n\n", .{});
}

test "load" {
    print("Load tracked files test:", .{});

    const allocator = std.testing.allocator;

    var tracked_files = TrackedFiles.init(allocator, "test_metadata.bin");

    defer if (tracked_files.files) |files| {
        @constCast(&files).deinit();
    };

    try tracked_files.load();

    var tracked = tracked_files.files orelse unreachable;

    var it = tracked.iterator();

    while (it.next()) |entry| {
        const file_name = entry.key_ptr.*;
        const metadata = entry.value_ptr.*;

        // Print each file and its metadata
        std.debug.print("File: {s}\n", .{file_name});
        std.debug.print("  State: {any}\n", .{@tagName(metadata.state)});
        std.debug.print("  Timestamp: {}\n", .{metadata.timestamp});
        std.debug.print("  Checksum: {s}\n", .{metadata.checksum});
        std.debug.print("  Size: {}\n", .{metadata.size});
    }

    const metadata = tracked.get("example.txt") orelse unreachable;

    defer {
        allocator.free(metadata.file_name);
        allocator.free(metadata.checksum);
    }

    try std.testing.expectEqualStrings(metadata.file_name, "example.txt");
    try std.testing.expectEqual(metadata.state, .Added);
    try std.testing.expectEqual(metadata.timestamp, 1679856000);
    try std.testing.expectEqualStrings(metadata.checksum, "abc123");
    try std.testing.expectEqual(metadata.size, 1024);
}
