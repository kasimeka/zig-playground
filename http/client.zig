const std = @import("std");

const Io = std.Io;
const net = std.Io.net;

pub fn main() !void {
    var allocator = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(allocator.deinit() == .ok);
    const gpa = allocator.allocator();

    var threaded = Io.Threaded.init(gpa);
    defer threaded.deinit();
    const io = threaded.io();

    const localhost = net.IpAddress{ .ip4 = .loopback(6969) };
    var connection = try localhost.connect(io, .{ .mode = .stream });

    var writer_buf: [64]u8 = undefined;
    var reader_buf: [64]u8 = undefined;
    var writer = connection.writer(io, &writer_buf);
    var reader = connection.reader(io, &reader_buf);

    writer.interface.print("henlo fren\n", .{}) catch {};
    writer.interface.print("how you doing\n", .{}) catch {};
    writer.interface.print("fr fr", .{}) catch {};

    writer.interface.flush() catch {};
    std.debug.print("{s}", .{reader.interface.peekGreedy(1) catch ""});
    connection.close(io);
}
