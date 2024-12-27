const std = @import("std");
const print = std.debug.print;

fn createProjectRootFile(allocator: std.mem.Allocator) !void {
    const cwd = std.fs.cwd();
    const root_path = try cwd.realpathAlloc(allocator, ".");

    // Create or overwrite the PROJECT_ROOT file
    var file = try cwd.createFile(".zigit/PROJECT_ROOT", .{});
    defer file.close();
    try file.writer().print("{s}\n", .{root_path});

    std.log.info("Project root stored in .zigit/PROJECT_ROOT: {s}", .{root_path});
}

fn createPath(base: []const u8, is_file: bool) !void {
    const cwd = std.fs.cwd();

    if (is_file) {
        // Create a file at the specified path
        var file = try cwd.createFile(base, .{});
        defer file.close();
        std.log.info("{s} file created successfully", .{base});
    } else {
        // Create a directory at the specified path
        const dir = try cwd.makeOpenPath(base, .{ .iterate = false });
        defer @constCast(&dir).close(); // Close the directory handle
        std.log.info("{s} directory is ready (created or already existed)", .{base});
    }
}

pub fn initZigGit(allocator: std.mem.Allocator) !void {
    // Create the .zigit structure
    try createPath(".zigit", false); // Create .zigit directory
    try createPath(".zigit/HEAD.txt", true); // Create HEAD.txt file
    try createPath(".zigit/objects", false); // Create objects directory
    try createPath(".zigit/refs", false); // Create refs directory
    try createPath(".zigit/refs/heads", false); // Create refs/heads directory
    try createPath(".zigit/refs/tags", false); // Create refs/tags directory
    try createPath(".zigit/index.bin", true); // Create index.json file
    // Initialize HEAD file
    var head_file = try std.fs.cwd().createFile(".zigit/HEAD.txt", .{});
    defer head_file.close();
    try head_file.writer().print("ref: refs/heads/main\n", .{});

    // Prepare JSON object for config
    const config_data = .{
        .core = .{
            .repositoryformatversion = 0,
            .filemode = true,
            .bare = false,
        },
    };

    const zigignore =
        \\
        \\.zigit 
    ;

    try writeJsonToFile(".zigit/config.json", config_data);
    try writeToFile(".zigit/.zigitignore", zigignore);
    try createProjectRootFile(allocator);
    std.log.info("All required directories and files for .zigit are successfully created or already existed.", .{});
}

pub fn repositoryExists(path: []const u8) !bool {
    const cwd = std.fs.cwd();
    var result = cwd.openDir(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };

    defer result.close();

    return true;
}

pub fn writeToFile(pathToFile: []const u8, content: []const u8) !void {
    const cwd = std.fs.cwd();

    var file = cwd.openFile(pathToFile, .{ .mode = .write_only }) catch |err| switch (err) {
        error.FileNotFound => try cwd.createFile(pathToFile, .{}), // Create the file if it doesn't exist
        else => return err, // Propagate other errors
    };
    defer file.close();

    try file.writer().print("{s}", .{content});
}

pub fn writeJsonToFile(pathToFile: []const u8, json: anytype) !void {
    const cwd = std.fs.cwd();

    // Try opening the file. If it doesn't exist, create it.
    var file = cwd.openFile(pathToFile, .{ .mode = .write_only }) catch |err| switch (err) {
        error.FileNotFound => try cwd.createFile(pathToFile, .{}), // Create the file if it doesn't exist
        else => return err, // Propagate other errors
    };
    defer file.close();

    // Serialize the JSON object and write to the file
    try std.json.stringify(json, .{}, file.writer());
}
