const std = @import("std");

pub const Base64 = struct {
    table: *const [64]u8 =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ++
        "abcdefghijklmnopqrstuvwxyz" ++
        "0123456789+/",

    const Self = @This();
    pub const init = Self{};

    pub fn encode(self: Base64, gpa: std.mem.Allocator, str: []const u8) ![]u8 {
        if (str.len == 0) return "";

        const ngroups = try std.math.divCeil(usize, str.len, 3);
        const outsize = 4 * ngroups;

        var out = try gpa.alloc(u8, outsize);

        for (0..ngroups) |g| {
            const str_offset = 3 * g;
            const count = @min(str.len - str_offset, 3);
            const group = str[str_offset .. str_offset + count];

            var buf: [4]u8 = undefined;
            buf[0] = group[0] >> 2;
            buf[1] = (0b0011 & group[0]) << 4 |
                if (group.len > 1) group[1] >> 4 else 0;
            buf[2] = (if (group.len > 1) (0b1111 & group[1]) << 2 else 0) |
                if (group.len > 2) group[2] >> 6 else 0;
            buf[3] = if (group.len > 2) (0b00111111 & group[2]) else 0;

            const out_offset = 4 * g;
            inline for (0..4) |n| {
                out[out_offset + n] = self.table[buf[n]];
            }
        }

        for (@subWithOverflow(out.len, 3).@"0"..out.len) |n| {
            if (out[n] == 'A') {
                out[n] = '=';
            }
        }

        return out;
    }
};
