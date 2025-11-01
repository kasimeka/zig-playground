const std = @import("std");
const base64 = @import("base64");

pub fn main() !void {
    const buf_len = 100;

    var in_buf: [buf_len]u8 = undefined;
    var stdin = std.fs.File.stdin().reader(&in_buf);

    var allocator = std.heap.DebugAllocator(.{}).init;
    const gpa = allocator.allocator();

    const argv = try std.process.argsAlloc(gpa);
    var op = &base64.encode;
    if (argv.len > 1 and std.mem.eql(u8, argv[1][0..2], "-d")) {
        op = &base64.decode;
    }
    std.process.argsFree(gpa, argv);

    const input = try stdin.interface.allocRemaining(gpa, .unlimited);
    const output = try op(gpa, input);
    defer gpa.free(output);

    var out_buf: [1.4 * buf_len]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&out_buf);
    try stdout.interface.print("{s}\n", .{output});
    try stdout.interface.flush();
}
