const std = @import("std");

const Tree = @import("./data_structures/tree.zig").Tree;
const cmd = @import("./commmands/commands.zig").CommandHandler;

const appendTreeValues = @import("./data_structures/tree.zig").appendTreeValues;
const print = std.debug.print;
const getCwdPath = @import("./repository/utils.zig").getCwdPath;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const args = try std.process.argsAlloc(allocator);
    const command_name = args[1];
    const command_args = args[2..];
    var command = try cmd.init(command_name, command_args, allocator);

    try command.execute(command.command);
}

// test "find .zigit dir" {
//     const allocator = std.testing.allocator;
//
//     const zigitRoot = try findZigitRoot("/Users/alex/projects/zig/zigit/src/commands", allocator);
//     std.debug.print("Type of zigitRoot: {any}\n\n", .{@TypeOf(zigitRoot)});
//
//     if (zigitRoot) |pathname| {
//         std.debug.print("zigit root path: {s}\n", .{pathname});
//         try std.testing.expect(std.mem.eql(u8, pathname, "/Users/alex/projects/zig/zigit"));
//         allocator.free(pathname); // Correctly free the allocated memory
//     } else {
//         try std.testing.expect(false); // Fail the test if zigitRoot is null
//     }
// }

// test "Simplified Tree appendValues" {
//     const allocator = std.testing.allocator;
//
//     var root = Tree([]const u8).init(allocator, "root", false);
//
//     defer {
//         if (root.children) |children| {
//             for (children.items) |child| {
//                 allocator.destroy(child);
//             }
//             children.deinit();
//         }
//     }
//
//     try root.addChild("child1", false);
//     try root.addChild("child2", false);
//
//     var collector = std.ArrayList([]const u8).init(allocator);
//     defer collector.deinit();
//
//     try appendTreeValues([]const u8, &root, &collector);
//     try std.testing.expectEqualStrings(collector.items[0], "root");
// }

// test "Tree functionality test with appendValues" {
//     const allocator = std.testing.allocator;
//
//     // Create the root node of the tree
//     var root = Tree([]const u8).init(allocator, "root", false);
//     @compileLog("Type of root: {any}", .{@TypeOf(root)});
//
//     defer {
//         if (root.children) |children| {
//             for (children.items) |*child| {
//                 allocator.destroy(child);
//             }
//             children.deinit();
//         }
//     }
//
//     try root.addChild("child1", false);
//     try root.addChild("child2", false);
//
//     if (root.children) |children| {
//         const child1 = children.items[0];
//         try child1.addChild("child1.1", true);
//     }
//
//     // Use `appendValues` to collect values into a list
//     var collector = std.ArrayList([]const u8).init(allocator);
//     defer collector.deinit();
//
//     try root.appendValues(&collector);
//
//     // Verify the traversal order
//     const expected = [_][]const u8{ "root", "child1", "child1.1", "child2" };
//     try std.testing.expectEqual(collector.items.len, expected.len);
//
//     for (collector.items, 0..) |item, idx| {
//         try std.testing.expectEqualStrings(item, expected[idx]);
//     }
// }

// stdout is for the actual output of your application, for example if you
// are implementing gzip, then only the compressed bytes should be sent to
// stdout, not any debugging messages.
// const stdout_file = std.io.getStdOut().writer();
// var bw = std.io.bufferedWriter(stdout_file);
// const stdout = bw.writer();
//
// try stdout.print("Run `zig build test` to run the tests.\n", .{});
//
// try bw.flush(); // don't forget to flush!
