const std = @import("std");
const print = std.debug.print;

pub fn iterateDir(dir_name: []const u8, allocator: std.mem.Allocator) !void {
    const path = try findFirstZigit(dir_name, allocator);

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
}

pub fn isNumeric(basename: []const u8) bool {
    for (basename) |c| {
        if (!std.ascii.isDigit(c)) {
            return false;
        }
    }
    return true;
}

pub fn shouldProcess(path: []const u8) bool {
    const unwanted_paths = [_][]const u8{ ".zig-cache", ".zigit" };
    const unwanted_extensions = [_][]const u8{ ".o", ".a", ".tmp", ".sample", ".bin" };

    // Check for unwanted substrings in the path
    for (unwanted_paths) |unwanted| {
        if (std.mem.indexOf(u8, path, unwanted) != null) {
            return false;
        }
    }

    // Extract the basename
    const basename = std.fs.path.basename(path);

    // Skip numeric-only files or specific basenames
    if (isNumeric(basename) or basename.len == 1 or std.mem.eql(u8, basename, "temp")) {
        return false;
    }

    // Check for unwanted extensions
    const ext = std.fs.path.extension(basename);
    if (ext.len == 0) {
        return false;
    }
    for (unwanted_extensions) |unwanted| {
        if (std.mem.eql(u8, ext, unwanted)) {
            return false;
        }
    }

    return true;
}

// pub fn shouldProcess(path: []const u8) bool {
//     // Check if the path contains `.zig-cache`
//     if (std.mem.indexOf(u8, path, ".zig-cache") != null) {
//         // print("Skipping path containing `.zig-cache`: {s}\n", .{path});
//         return false;
//     }
//
//     if (std.mem.indexOf(u8, path, ".zigit") != null) {
//         return false;
//     }
//
//     // Extract the basename for further checks
//     const basename = std.fs.path.basename(path);
//
//     // Skip numeric-only files
//     if (isNumeric(basename)) {
//         return false;
//     }
//
//     if (basename.len == 1 or std.mem.eql(u8, basename, "temp")) {
//         return false;
//     }
//
//     // Skip specific extensions
//     const ext = std.fs.path.extension(basename);
//     if (ext.len == 0) {
//         return false;
//     }
//
//     const unwanted_extensions = [_][]const u8{ ".o", ".a", ".tmp", ".sample", ".bin" };
//     for (unwanted_extensions) |unwanted| {
//         if (std.mem.eql(u8, ext, unwanted)) {
//             return false;
//         }
//     }
//
//     return true;
// }

pub fn findFirstZigit(
    start_dir: []const u8,
    allocator: std.mem.Allocator, // Passed by value
) !?[]const u8 {
    const fs = std.fs;
    var cwd = fs.cwd(); // Get the current working directory

    // Resolve the start_dir to an absolute path.
    var current_path = try cwd.realpathAlloc(allocator, start_dir);

    print("Start directory: {s}\n\n", .{current_path});

    while (true) {
        std.debug.print("Checking: {s}\n", .{current_path});

        // Open the current directory
        var dir = try cwd.openDir(current_path, .{});
        defer dir.close();

        // Use `statFile` to check if `.zigit` exists and is a directory
        const stat_result = dir.statFile(".zigit") catch |err| switch (err) {
            error.FileNotFound => null, // `.zigit` not found in this directory
            else => return err, // Other errors
        };

        if (stat_result) |s| {
            // Check if the found `.zigit` is a directory
            if (s.kind == .directory) {
                std.debug.print("Found `.zigit` in: {s}\n", .{current_path});
                return current_path; // Return the slice where `.zigit` was found
            }
        }

        // Move up to the parent directory
        const parent_path_opt = fs.path.dirname(current_path);

        if (parent_path_opt) |path| {
            std.debug.print("Moving to parent: {s}\n", .{path});
            if (std.mem.eql(u8, path, current_path)) {
                // Reached the root directory, stop searching
                std.debug.print("Reached root. `.zigit` not found.\n", .{});
                break;
            }
            const duplicated_path = try allocator.dupe(u8, path); // Duplicate the parent path
            allocator.free(current_path); // Free the previous allocation
            current_path = duplicated_path; // Assign the duplicated path

        } else {
            // If dirname returns null, stop searching
            std.debug.print("Failed to get parent path. `.zigit` not found.\n", .{});
            break;
        }
    }

    return null;
}
