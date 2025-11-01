const std = @import("std");

pub const CHARS: *const [64]u8 =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ++
    "abcdefghijklmnopqrstuvwxyz" ++
    "0123456789+/";
pub const CHARS_REV: [256]u8 = result: {
    const INVALID_SENTINEL = 0;
    var indices: [256]u8 = @splat(INVALID_SENTINEL);
    for (0.., CHARS) |index, char| {
        indices[char] = index;
    }
    break :result indices;
};

const PLAIN_GROUP_SIZE = 3;
const ENCODED_GROUP_SIZE = 4;

pub fn encode(gpa: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) return "";

    const group_count = try std.math.divCeil(usize, input.len, PLAIN_GROUP_SIZE);
    var output = try gpa.alloc(u8, ENCODED_GROUP_SIZE * group_count);

    var group_buf: [PLAIN_GROUP_SIZE]u8 = undefined;
    for (0..group_count) |g| {
        const group_offset_in_input = PLAIN_GROUP_SIZE * g;

        const group_len = @min(PLAIN_GROUP_SIZE, input.len - group_offset_in_input);
        @memcpy(group_buf[0..group_len], input[group_offset_in_input..][0..group_len]);
        @memset(group_buf[group_len..], 0);

        const group_offset_in_output = ENCODED_GROUP_SIZE * g;
        const out_group = output[group_offset_in_output..][0..ENCODED_GROUP_SIZE];
        out_group[0] = CHARS[group_buf[0] >> 2];
        out_group[1] = CHARS[(0b0011 & group_buf[0]) << 4 | group_buf[1] >> 4];
        out_group[2] = CHARS[(0b1111 & group_buf[1]) << 2 | group_buf[2] >> 6];
        out_group[3] = CHARS[0b00111111 & group_buf[2]];
    }

    const pad_len =
        (PLAIN_GROUP_SIZE - input.len % PLAIN_GROUP_SIZE) % PLAIN_GROUP_SIZE;
    for (0..pad_len) |n| {
        output[output.len - 1 - n] = '=';
    }

    return output;
}

pub fn decode(gpa: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) return "";

    const group_count = try std.math.divCeil(usize, input.len, ENCODED_GROUP_SIZE);
    const pad_len = result: for (0..PLAIN_GROUP_SIZE) |n| {
        if (input[input.len - 1 - n] != '=') {
            break :result n;
        }
    } else unreachable;
    const output = try gpa.alloc(u8, PLAIN_GROUP_SIZE * group_count - pad_len);

    var group_buf: [PLAIN_GROUP_SIZE]u8 = undefined;
    for (0..group_count) |g| {
        const group_offset_in_input = ENCODED_GROUP_SIZE * g;
        const in_group = input[group_offset_in_input..];
        const group_offset_in_output = PLAIN_GROUP_SIZE * g;

        group_buf[0] =
            (CHARS_REV[in_group[0]] << 2) | (0b0011 & (CHARS_REV[in_group[1]] >> 4));
        group_buf[1] =
            (CHARS_REV[in_group[1]] << 4) | (0b1111 & (CHARS_REV[in_group[2]] >> 2));
        group_buf[2] =
            (CHARS_REV[in_group[2]] << 6) | (0b00111111 & (CHARS_REV[in_group[3]]));

        const out_group = output[group_offset_in_output..];
        const group_len = @min(PLAIN_GROUP_SIZE, out_group.len);
        @memcpy(out_group[0..group_len], group_buf[0..group_len]);
    }

    return output;
}

test "encode" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    var allocator = std.heap.ArenaAllocator.init(gpa.allocator());
    defer allocator.deinit();
    const arena = allocator.allocator();

    try std.testing.expectEqualSlices(
        u8,
        "aGVubG8gZnJlbiwgaG93IHUgZG9pbiBmciBmcg==",
        try encode(arena, "henlo fren, how u doin fr fr"),
    );
    try std.testing.expectEqualSlices(
        u8,
        "aGVubG8=",
        try encode(arena, "henlo"),
    );
    try std.testing.expectEqualSlices(
        u8,
        "aGVubG9v",
        try encode(arena, "henloo"),
    );
    try std.testing.expectEqualSlices(
        u8,
        "aGVubG9vbw==",
        try encode(arena, "henlooo"),
    );
}

test "decode" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    var allocator = std.heap.ArenaAllocator.init(gpa.allocator());
    defer allocator.deinit();
    const arena = allocator.allocator();

    try std.testing.expectEqualSlices(
        u8,
        "Whereas recognition of the inherent dignity and of the equal and inalienable rights of all members of the human family is the foundation of freedom, justice and peace in the world",
        try decode(
            arena,
            "V2hlcmVhcyByZWNvZ25pdGlvbiBvZiB0aGUgaW5oZXJlbnQgZGlnbml0eSBhbmQgb2YgdGhlIGVxdWFsIGFuZCBpbmFsaWVuYWJsZSByaWdodHMgb2YgYWxsIG1lbWJlcnMgb2YgdGhlIGh1bWFuIGZhbWlseSBpcyB0aGUgZm91bmRhdGlvbiBvZiBmcmVlZG9tLCBqdXN0aWNlIGFuZCBwZWFjZSBpbiB0aGUgd29ybGQ=",
        ),
    );
    try std.testing.expectEqualSlices(
        u8,
        "henlo",
        try decode(arena, "aGVubG8="),
    );
    try std.testing.expectEqualSlices(
        u8,
        "henloo",
        try decode(arena, "aGVubG9v"),
    );
    try std.testing.expectEqualSlices(
        u8,
        "henlooo",
        try decode(arena, "aGVubG9vbw=="),
    );
}
