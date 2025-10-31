const std = @import("std");
const base64 = @import("base64");

pub fn main() !void {
    const buf_len = 100;

    var in_buf: [buf_len]u8 = undefined;
    var stdin = std.fs.File.stdin().reader(&in_buf);

    var allocator = std.heap.DebugAllocator(.{}).init;
    const gpa = allocator.allocator();

    const str = try stdin.interface.allocRemaining(gpa, .unlimited);
    const b64 = try base64.encode(gpa, str);
    defer gpa.free(b64);

    var out_buf: [1.4 * buf_len]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&out_buf);
    try stdout.interface.print("{s}\n", .{b64});
    try stdout.interface.flush();
}
