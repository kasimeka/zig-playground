const std = @import("std");
const base64 = @import("base64");

pub fn main() !void {
    const buf_len = 100;

    var in_buf: [buf_len]u8 = undefined;
    var stdin = std.fs.File.stdin().reader(&in_buf);

    var allocator = std.heap.DebugAllocator(.{}).init;
    const gpa = allocator.allocator();

    const argv = try std.process.argsAlloc(gpa);
    const decode_mode = argv.len > 1 and std.mem.eql(u8, argv[1][0..2], "-d");
    const op = if (decode_mode) &base64.decode else &base64.encode;
    std.process.argsFree(gpa, argv);

    const input = try stdin.interface.allocRemaining(gpa, .unlimited);
    const output = try op(gpa, input);
    defer gpa.free(output);

    var out_buf: [1.4 * buf_len]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&out_buf);
    try stdout.interface.print("{s}{s}", .{ output, if (decode_mode) "" else "\n" });
    try stdout.interface.flush();
}
