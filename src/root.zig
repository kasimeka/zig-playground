const std = @import("std");

pub const char_table: *const [64]u8 =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ++
    "abcdefghijklmnopqrstuvwxyz" ++
    "0123456789+/";

const PLAIN_GROUP_SIZE = 3;
const ENCODED_GROUP_SIZE = 4;

pub fn encode(gpa: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) return "";

    const group_count = try std.math.divCeil(usize, input.len, PLAIN_GROUP_SIZE);
    var output = try gpa.alloc(u8, ENCODED_GROUP_SIZE * group_count);

    for (0..group_count) |g| {
        const group_offset_in_input = PLAIN_GROUP_SIZE * g;

        const group_len = @min(PLAIN_GROUP_SIZE, input.len - group_offset_in_input);
        var group_buf: [PLAIN_GROUP_SIZE]u8 = @splat(0);
        @memcpy(group_buf[0..group_len], input[group_offset_in_input..][0..group_len]);

        const group_offset_in_output = ENCODED_GROUP_SIZE * g;
        const out_group = output[group_offset_in_output..][0..ENCODED_GROUP_SIZE];
        out_group[0] = char_table[group_buf[0] >> 2];
        out_group[1] = char_table[(0b0011 & group_buf[0]) << 4 | group_buf[1] >> 4];
        out_group[2] = char_table[(0b1111 & group_buf[1]) << 2 | group_buf[2] >> 6];
        out_group[3] = char_table[0b00111111 & group_buf[2]];
    }

    const pad_len =
        (PLAIN_GROUP_SIZE - input.len % PLAIN_GROUP_SIZE) % PLAIN_GROUP_SIZE;
    for (0..pad_len) |n| {
        output[output.len - 1 - n] = '=';
    }

    return output;
}

pub fn decode(gpa: std.mem.Allocator, str: []const u8) ![]u8 {
    if (str.len == 0) return "";
    const ngroups = try std.math.divCeil(usize, str.len, ENCODED_GROUP_SIZE);
    const outsize = PLAIN_GROUP_SIZE * ngroups;

    const out = try gpa.alloc(u8, outsize);

    _ = out;

    return &[0]u8{};
}

test "encode" {
    var allocator = std.heap.DebugAllocator(.{}).init;
    const gpa = allocator.allocator();

    const b64 = try encode(gpa, "henlo fren");
    defer gpa.free(b64);

    try std.testing.expectEqualSlices(u8, b64, "aGVubG8gZnJlbg==");
}
