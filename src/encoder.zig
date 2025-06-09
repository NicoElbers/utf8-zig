// TODO: Once the IO update drops change this API into a source/sink

pub fn encode(codepoint: CodePoint, bytes: *[4]u8) []const u8 {
    return encodeStrict(codepoint, bytes) catch
        encodeStrict(invalid_codepoint, bytes) catch unreachable;
}

pub fn encodeStrict(codepoint: CodePoint, bytes: *[4]u8) error{InvalidCodePoint}![]const u8 {
    // if (@import("builtin").is_test) return encodeStrict2(codepoint, bytes);

    const trunc = struct {
        inline fn trunc(cp: u21) u8 {
            return @as(u6, @truncate(cp));
        }
    }.trunc;

    if (codepoint <= 0b0111_1111) {
        bytes[0] = @intCast(codepoint);
        return bytes[0..1];
    } else if (codepoint <= 0x7FF) {
        // 2 byte
        bytes[0] = trunc(codepoint >> 6) | 0xC0;
        bytes[1] = trunc(codepoint >> 0) | 0x80;
        return bytes[0..2];
    } else if (codepoint <= 0xFFFF) {
        // 3 byte
        bytes[0] = trunc(codepoint >> 12) | 0xE0;
        bytes[1] = trunc(codepoint >> 6) | 0x80;
        bytes[2] = trunc(codepoint >> 0) | 0x80;
        return bytes[0..3];
    } else if (codepoint <= 0x10FFFF) {
        // 4 byte
        bytes[0] = trunc(codepoint >> 18) | 0xF0;
        bytes[1] = trunc(codepoint >> 12) | 0x80;
        bytes[2] = trunc(codepoint >> 6) | 0x80;
        bytes[3] = trunc(codepoint >> 0) | 0x80;
        return bytes[0..4];
    } else {
        @branchHint(.unlikely);
        return error.InvalidCodePoint;
    }
}

pub fn isValid(codepoint: CodePoint) bool {
    // Highest valid codepoint: 0b1_0000_1111_1111_1111_1111
    return codepoint & 0b1_0000_0000_0000_0000_0000 != 0b1_0000_0000_0000_0000_0000 or
        @clz(codepoint & 0b0_1111_1111_1111_1111_1111) > 4;
}

test isValid {
    for (0..0x10FFFF + 1) |point|
        try std.testing.expectEqual(true, isValid(@intCast(point)));

    for (0x10FFFF + 1..std.math.maxInt(u21) + 1) |point|
        try std.testing.expectEqual(false, isValid(@intCast(point)));
}

test "sanity" {
    const tst = struct {
        fn tst(expect: []const u8, codepoint: CodePoint) !void {
            var buf: [4]u8 = undefined;
            const encoded = try encodeStrict(codepoint, &buf);
            try std.testing.expectEqualSlices(u8, expect, encoded);
        }
    }.tst;
    try tst("€", '€');
    try tst("∑", '∑');
    try tst("⭐", '⭐');
}

test "ascii" {
    const expectEqualSlices = std.testing.expectEqualSlices;

    var buf: [4]u8 = undefined;
    for (0b0000_0000..0b0111_1111 + 1) |point| {
        const encoded = try encodeStrict(@intCast(point), &buf);
        try expectEqualSlices(u8, &.{@intCast(point)}, encoded);
    }
}

test "2 byte characters" {
    const expectEqualSlices = std.testing.expectEqualSlices;

    var buf: [4]u8 = undefined;
    for (0x80..0x7FF + 1) |point| {
        const encoded = try encodeStrict(@intCast(point), &buf);
        const expected: [2]u8 = .{
            @as(u8, @intCast(point >> 6)) | 0xC0,
            @as(u8, @truncate((point >> 0) & 0x3F)) | 0x80,
        };
        try expectEqualSlices(u8, &expected, encoded);
    }
}

test "3 byte characters" {
    const expectEqualSlices = std.testing.expectEqualSlices;

    var buf: [4]u8 = undefined;
    for (0x800..0xFFFF + 1) |point| {
        const encoded = try encodeStrict(@intCast(point), &buf);
        const expected: [3]u8 = .{
            @as(u8, @intCast(point >> 12)) | 0xE0,
            @as(u8, @truncate((point >> 6) & 0x3F)) | 0x80,
            @as(u8, @truncate((point >> 0) & 0x3F)) | 0x80,
        };
        try expectEqualSlices(u8, &expected, encoded);
    }
}

test "4 byte characters" {
    const expectEqualSlices = std.testing.expectEqualSlices;

    var buf: [4]u8 = undefined;
    for (0x10000..0x10FFFF + 1) |point| {
        const encoded = try encodeStrict(@intCast(point), &buf);
        const expected: [4]u8 = .{
            @as(u8, @intCast(point >> 18)) | 0xF0,
            @as(u8, @truncate((point >> 12) & 0x3F)) | 0x80,
            @as(u8, @truncate((point >> 6) & 0x3F)) | 0x80,
            @as(u8, @truncate((point >> 0) & 0x3F)) | 0x80,
        };
        try expectEqualSlices(u8, &expected, encoded);
    }
}

test "overlong characters" {
    const expectError = std.testing.expectError;

    var buf: [4]u8 = undefined;
    for (0x10FFFF + 1..std.math.maxInt(u21) + 1) |point| {
        try expectError(error.InvalidCodePoint, encodeStrict(@intCast(point), &buf));
    }
}

const std = @import("std");
const root = @import("root.zig");

const assert = std.debug.assert;
const invalid_codepoint = root.invalid_codepoint;

const CodePoint = root.CodePoint;
const CodePointLen = root.CodePointLen;
