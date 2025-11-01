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

    const group_count = std.math.divCeil(usize, input.len, PLAIN_GROUP_SIZE) catch unreachable;
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

    const group_count = std.math.divCeil(usize, input.len, ENCODED_GROUP_SIZE) catch unreachable;
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

const test_random_bytes = [_]u8{ 0xa2, 0xf8, 0xfd, 0x2c, 0x70, 0x87, 0x53, 0xff, 0xe2, 0xf1, 0x98, 0xbf, 0x68, 0xa6, 0x10, 0x66, 0x23, 0x08, 0xcd, 0x99, 0x2a, 0xdc, 0xd9, 0xc9, 0x01, 0x74, 0x6f, 0x07, 0x34, 0x1e, 0xb4, 0x4d, 0xd6, 0xe7, 0x5d, 0x4d, 0x12, 0x2d, 0x63, 0x0c, 0x85, 0x6f, 0x4d, 0x93, 0x95, 0x77, 0xd0, 0xd2, 0xd5, 0x9a, 0x20, 0x35, 0xc4, 0xd2, 0x4a, 0x47, 0x6f, 0x65, 0xe1, 0x3f, 0x39, 0x6c, 0x5b, 0xce, 0xe4, 0x37, 0x24, 0xc9, 0x5c, 0xc5, 0xc6, 0x41, 0xae, 0x18, 0xf9, 0xa1, 0xf4, 0xc5, 0xbf, 0x10, 0x35, 0x89, 0xa3, 0xcb, 0x27, 0x90, 0xb1, 0x44, 0x76, 0x60, 0x6e, 0x40, 0xee, 0xb1, 0x79, 0xaf, 0xee, 0x68, 0xa7, 0x9c, 0x44, 0xba, 0x92, 0x7c, 0x69, 0xfe, 0x3a, 0x3b, 0xe1, 0xdd, 0xc5, 0xd8, 0x25, 0x89, 0x7f, 0x4e, 0xda, 0xc1, 0x99, 0x2c, 0xe3, 0xad, 0x69, 0x51, 0x5a, 0x7c, 0x87, 0x8b };

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

    try std.testing.expectEqualSlices(
        u8,
        "ovj9LHCHU//i8Zi/aKYQZiMIzZkq3NnJAXRvBzQetE3W511NEi1jDIVvTZOVd9DS1ZogNcTSSkdvZeE/OWxbzuQ3JMlcxcZBrhj5ofTFvxA1iaPLJ5CxRHZgbkDusXmv7minnES6knxp/jo74d3F2CWJf07awZks461pUVp8h4s=",
        try encode(arena, &test_random_bytes),
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
    try std.testing.expectEqualSlices(
        u8,
        &test_random_bytes,
        try decode(
            arena,
            "ovj9LHCHU//i8Zi/aKYQZiMIzZkq3NnJAXRvBzQetE3W511NEi1jDIVvTZOVd9DS1ZogNcTSSkdvZeE/OWxbzuQ3JMlcxcZBrhj5ofTFvxA1iaPLJ5CxRHZgbkDusXmv7minnES6knxp/jo74d3F2CWJf07awZks461pUVp8h4s=",
        ),
    );
}
