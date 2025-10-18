const std = @import("std");
const base64 = @import("base64"); // my implementation

pub fn main() !void {
    const buf_len = 100;

    var out_buf: [buf_len]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&out_buf);

    var in_buf: [buf_len]u8 = undefined;
    var stdin = std.fs.File.stdin().reader(&in_buf);

    // i lowk hate this
    var n: u8 = 0;
    var read_buf: [buf_len]u8 = undefined;
    while (stdin.interface.takeByte()) |c| {
        read_buf[n] = c;
        n += 1;
    } else |e| {
        if (e != error.EndOfStream) return e;
    }
    const str = read_buf[0..n];
    // is it really the best i can do?

    var allocator = std.heap.DebugAllocator(.{}).init;
    defer _ = allocator.deinit();
    const gpa = allocator.allocator();

    const b64 = try base64.Base64.init.encode(gpa, str);
    defer gpa.free(b64);

    try stdout.interface.print("{s}\n", .{b64});
    try stdout.interface.flush();
}
