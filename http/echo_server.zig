const std = @import("std");

const Io = std.Io;
const Thread = std.Thread;
const log = std.log;
const mem = std.mem;
const net = Io.net;

const IPV4_ADDR_BUFSIZE = 21;
const REQ_BUFSIZE = 1024;
const RES_BUFSIZE = 1024;

fn handler(gpa: mem.Allocator, io: Io, connection: net.Stream) !void {
    _ = gpa;

    var address_buf: [IPV4_ADDR_BUFSIZE]u8 = undefined;
    var address_w = Io.Writer.fixed(&address_buf);
    const address =
        if (connection.socket.address.ip4.format(&address_w))
            address_w.buffered()
        else |_|
            "<unknown host>";

    log.info("`{s}` connected", .{address});
    defer {
        connection.close(io);
        log.info("`{s}` closed", .{address});
    }

    var reader_buf: [REQ_BUFSIZE]u8 = undefined;
    var writer_buf: [RES_BUFSIZE]u8 = undefined;
    var reader = connection.reader(io, &reader_buf);
    var writer = connection.writer(io, &writer_buf);

    const HTTP_DELIMETER = "\r\n\r\n";
    while (true) {
        const request = reader.interface.peekGreedy(1) catch |err|
            switch (err) {
                error.EndOfStream => return,
                else => return err,
            };
        reader.interface.toss(request.len);

        if (std.mem.eql(
            u8,
            request[request.len - HTTP_DELIMETER.len .. request.len],
            HTTP_DELIMETER,
        )) {
            log.debug("`{s}` wrote HTTP-like message", .{address});
            try writer.interface.writeAll(
                \\HTTP/1.1 200
                \\Content-Type: text/html; charset=us-ascii
            ++ "\r\n\r\n" ++
                \\<!DOCTYPE HTML>
                \\<html lang="en">
                \\<head>
                \\  <style type="text/css">
                \\    :root { color-scheme: light dark; }
                \\  </style>
                \\  <title>henlo fren</title>
                \\</head>
                \\<body>
                \\  <h1>hysm and mazen</h1>
                \\</body>
                \\</html>
            ++ "\r\n\r\n");
            try writer.interface.flush();
            return;
        }

        if (writer.interface.writeAll(request)) {
            log.debug("`{s}` wrote: {s}", .{ address, request[0 .. request.len - 1] });
        } else |err| {
            log.err("failed to write response: {any}", .{err});
        }
        try writer.interface.flush();
    }
}

pub fn main(init: std.process.Init.Minimal) !void {
    var allocator = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(allocator.deinit() == .ok);
    const gpa = allocator.allocator();

    var threaded = Io.Threaded.init(gpa, .{ .environ = init.environ });
    defer threaded.deinit();
    const io = threaded.io();

    const localhost = net.IpAddress{ .ip4 = .loopback(6969) };
    var server = try localhost.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);

    while (true) {
        const connection = try server.accept(io); // blocks until a client connects
        _ = io.async(handler, .{ gpa, io, connection });
    }
}
