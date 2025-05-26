pub fn encodePoint(codepoint: CodePoint, bytes: *[4]u8) []const u8 {
    const len: CodePointLen = switch (codepoint) {
        0x00000...0x0007F => {
            bytes[0] = @intCast(codepoint);
            return bytes[0..1];
        },
        0x00080...0x007FF => blk: {
            bytes[0] = @intCast((codepoint >> 6) + 0xC0);
            break :blk .@"2";
        },
        0x00800...0x00FFFF => blk: {
            bytes[0] = @intCast((codepoint >> 12) + 0xE0);
            break :blk .@"3";
        },
        0x10000...0x10FFFF => blk: {
            bytes[0] = @intCast((codepoint >> 18) + 0xF0);
            break :blk .@"4";
        },
        else => {
            // 0xFFFD encodes gives { 0xEF, 0xBF, 0xBD }
            bytes[0] = 0xEF;
            bytes[1] = 0xBF;
            bytes[2] = 0xBD;
            return bytes[0..3];
        },
    };

    var count: u5 = len.toLen() - 1;
    var i: usize = 1;
    while (count > 0) : ({
        count -= 1;
        i += 1;
    }) {
        const temp: u8 = @truncate(codepoint >> (6 * (count - 1)));

        bytes[i] = 0x80 | (temp & 0x3F);
    }

    return bytes[0..len.toLen()];
}

const std = @import("std");
const root = @import("root.zig");

const assert = std.debug.assert;
const invalid_codepoint = root.invalid_codepoint;

const CodePoint = root.CodePoint;
const CodePointLen = root.CodePointLen;
