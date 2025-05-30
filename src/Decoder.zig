//! UTF8 decoder
//!
//! Maps all invalid characters, to `0xFFFD`
//!
//! This implementation works on slices until the zig IO rewrite happens.

source: []const u8,
curr: usize = 0,

const Decoder = @This();

pub const empty: Decoder = .{ .source = &.{} };

pub fn init(source: []const u8) Decoder {
    return .{ .source = source };
}

pub fn remainingLength(self: *const Decoder) usize {
    var len: usize = 0;
    for (self.source[self.curr..]) |byte| {
        // If not a continuation, we have a new codepoint
        if ((byte & 0xC0) != 0x80)
            len += 1;
    }
    return len;
}

pub fn decodeRemaining(self: *Decoder, gpa: Allocator) Allocator.Error![]const CodePoint {
    defer self.* = .empty;

    // Allocate everything at once
    var sink: ArrayListUnmanaged(u21) = try .initCapacity(gpa, self.source.len);
    errdefer sink.deinit(gpa);

    var source = self.source[self.curr..];
    while (source.len >= 4) {
        @branchHint(.likely);
        const bytes: *const [4]u8 = source[0..4];
        const point: CodePoint, const len = decodeBytes(bytes);

        source = source[len.toLen()..];

        sink.appendAssumeCapacity(point);
    }

    assert(source.len < 4);

    while (source.len > 0) {
        var bytes: [4]u8 = undefined;
        @memcpy(bytes[0..source.len], source);

        const point: CodePoint, const len = decodeBytes(&bytes);

        if (source.len < len.toLen()) {
            // Incomplete character
            sink.appendAssumeCapacity(invalid_codepoint);
            break;
        }

        source = source[len.toLen()..];

        sink.appendAssumeCapacity(point);
    }

    // Remap once here, worst case this is allocation 2 and we have to memcpy
    return sink.toOwnedSlice(gpa);
}

test decodeRemaining {
    const gpa = std.testing.allocator;

    const in = "hi🙂!\xFF!";
    const out: []const u21 = &.{ 'i', '🙂', '!', invalid_codepoint, '!' };
    var utf8: Decoder = .init(in);

    _ = utf8.next();

    const found = try utf8.decodeRemaining(gpa);
    defer gpa.free(found);

    try std.testing.expectEqualSlices(u21, out, found);
}

pub fn next(self: *Decoder) ?CodePoint {
    if (self.curr >= self.source.len) return null;

    const remaining = self.source[self.curr..];
    if (remaining.len >= 4) {
        @branchHint(.likely);

        const bytes: *const [4]u8 = remaining[0..4];
        const point, const len = decodeBytes(bytes);
        self.curr += len.toLen();
        return point;
    } else {
        var bytes: [4]u8 = undefined;
        @memcpy(bytes[0..remaining.len], remaining);
        const point, const len = decodeBytes(&bytes);
        self.curr += len.toLen();

        if (remaining.len < len.toLen()) {
            @branchHint(.unlikely);

            return invalid_codepoint;
        }

        return point;
    }
}

test next {
    const in = "hi🙂!\xFF!";
    var utf8: Decoder = .init(in);

    try std.testing.expectEqual('h', utf8.next());
    try std.testing.expectEqual('i', utf8.next());
    try std.testing.expectEqual('🙂', utf8.next());
    try std.testing.expectEqual('!', utf8.next());
    try std.testing.expectEqual(invalid_codepoint, utf8.next());
    try std.testing.expectEqual('!', utf8.next());
    try std.testing.expectEqual(null, utf8.next());
}

/// Internal implementation function
///
/// Decodes 4 bytes into a valid codepoint.
///
/// Decodes invalid codepoints into 0xFFFD.
///
/// Based on https://encoding.spec.whatwg.org/#utf-8-decoder
fn decodeBytes(bytes: *const [4]u8) struct { CodePoint, CodePointLen } {
    var codepoint: CodePoint = 0;
    var lower_bound: CodePoint = 0x80;
    var upper_bound: CodePoint = 0xBF;

    const length: CodePointLen = switch (bytes[0]) {
        0x00...0x7F => return .{ bytes[0], .@"1" },
        0xC2...0xDF => blk: {
            codepoint = bytes[0] & 0x1F;
            break :blk .@"2";
        },
        0xE0...0xEF => blk: {
            if (bytes[0] == 0xE0)
                lower_bound = 0xA0;

            if (bytes[0] == 0xED)
                upper_bound = 0x9F;

            codepoint = bytes[0] & 0xF;
            break :blk .@"3";
        },
        0xF0...0xF4 => blk: {
            if (bytes[0] == 0xF0)
                lower_bound = 0x90;

            if (bytes[0] == 0xF4)
                upper_bound = 0x8F;

            codepoint = bytes[0] & 0x7;

            break :blk .@"4";
        },
        else => return .{ invalid_codepoint, .@"1" },
    };

    for (1..length.toLen()) |index| {
        const byte = bytes[index];

        if (byte < lower_bound or byte > upper_bound)
            return .{ invalid_codepoint, .from(@intCast(index)) };

        lower_bound = 0x80;
        upper_bound = 0xBF;

        codepoint <<= 6;
        codepoint |= byte & 0x3F;
    }

    return .{ codepoint, length };
}

test decodeBytes {
    // Test reasoning from bitwise logic

    const expectEqual = std.testing.expectEqual;
    const bot_mask: u8 = 0b0011_1111;

    // Len == 1
    for (0b0000_0000..0b0111_1111 + 1) |byte| {
        const bytes: [4]u8 = .{ @intCast(byte), undefined, undefined, undefined };
        const expect: CodePoint = @intCast(byte);

        const point, const len = decodeBytes(&bytes);

        try expectEqual(CodePointLen.@"1", len);
        try expectEqual(expect, point);
    }

    // Len == 2
    for (0b1000_0000..0b1011_1111 + 1) |byte| {
        const bytes: [4]u8 = .{ 0b1101_0101, @intCast(byte), undefined, undefined };
        const expect: CodePoint = 0 |
            (0b1_0101 << 6) |
            @as(CodePoint, @as(u6, @intCast(byte & bot_mask)));

        const point, const len = decodeBytes(&bytes);

        try expectEqual(CodePointLen.@"2", len);
        try expectEqual(expect, point);
    }

    // Len == 3
    for (0b1000_0000..0b1011_1111 + 1) |byte| {
        const bytes: [4]u8 = .{ 0b1110_1010, 0b1010_1011, @intCast(byte), undefined };
        const expect: CodePoint = 0 |
            (0b1010 << 12) |
            (0b10_1011 << 6) |
            @as(CodePoint, @as(u6, @intCast(byte & bot_mask)));

        const point, const len = decodeBytes(&bytes);

        try expectEqual(CodePointLen.@"3", len);
        try expectEqual(expect, point);
    }

    // Len == 4
    for (0b1000_0000..0b1011_1111 + 1) |byte| {
        const bytes: [4]u8 = .{ 0b1111_0001, 0b1001_0101, 0b1001_0101, @intCast(byte) };
        const expect: CodePoint = 0 |
            (0b0000_0001 << 18) |
            (0b0101_0101 << 12) |
            (0b0101_0101 << 6) |
            @as(CodePoint, @as(u6, @intCast(byte & bot_mask)));

        const point, const len = decodeBytes(&bytes);

        try expectEqual(CodePointLen.@"4", len);
        try expectEqual(expect, point);
    }
}

test "Invalid mappings" {
    const tst = struct {
        pub fn tst(expect: []const u21, input: []const u8) !void {
            var utf8: Decoder = .init(input);

            for (expect) |point| {
                const found = utf8.next();
                try std.testing.expectEqual(point, found);
            }
            try std.testing.expectEqual(null, utf8.next());
        }
    }.tst;

    try tst(&.{}, "");
    try tst(&.{ 'f', 'o', 'o' }, "foo");
    try tst(&.{'𐐷'}, "𐐷");

    // Table 3-8. U+FFFD for Non-Shortest Form Sequences
    try tst(&.{ '�', '�', '�', '�', '�', '�', '�', '�', 'A' }, "\xC0\xAF\xE0\x80\xBF\xF0\x81\x82A");

    // Table 3-9. U+FFFD for Ill-Formed Sequences for Surrogates
    try tst(&.{ '�', '�', '�', '�', '�', '�', '�', '�', 'A' }, "\xED\xA0\x80\xED\xBF\xBF\xED\xAFA");

    // Table 3-10. U+FFFD for Other Ill-Formed Sequences
    try tst(&.{ '�', '�', '�', '�', '�', 'A', '�', '�', 'B' }, "\xF4\x91\x92\x93\xFFA\x80\xBFB");

    // Table 3-11. U+FFFD for Truncated Sequences
    try tst(&.{ '�', '�', '�', '�', 'A' }, "\xE1\x80\xE2\xF0\x91\x92\xF1\xBFA");
}

test "decodeBytes sanity" {
    {
        const in = "a";
        const buf: *const [4]u8 = in ++ ("\x00" ** 3);
        const point, _ = decodeBytes(buf);
        try std.testing.expectEqual('a', point);
    }
    {
        const in = "×";
        const buf: *const [4]u8 = in ++ ("\x00" ** 2);
        const point, _ = decodeBytes(buf);
        try std.testing.expectEqual('×', point);
    }
    {
        const in = "з";
        const buf: *const [4]u8 = in ++ ("\x00" ** 2);
        const point, _ = decodeBytes(buf);
        try std.testing.expectEqual('з', point);
    }
    {
        const in = "€";
        const buf: *const [4]u8 = in ++ ("\x00" ** 1);
        const point, _ = decodeBytes(buf);
        try std.testing.expectEqual('€', point);
    }
    {
        const in = "⚡";
        const buf: *const [4]u8 = in ++ ("\x00" ** 1);
        const point, _ = decodeBytes(buf);
        try std.testing.expectEqual('⚡', point);
    }
    {
        const in = "ㄊ";
        const buf: *const [4]u8 = in ++ ("\x00" ** 1);
        const point, _ = decodeBytes(buf);
        try std.testing.expectEqual('ㄊ', point);
    }
    {
        const in = "𝆑";
        const buf: *const [4]u8 = in;
        const point, _ = decodeBytes(buf);
        try std.testing.expectEqual('𝆑', point);
    }
    {
        const in = "🂪";
        const buf: *const [4]u8 = in;
        const point, _ = decodeBytes(buf);
        try std.testing.expectEqual('🂪', point);
    }
}

test "decodeBytes exhaustive valid" {
    // All valid UTF8 characters
    for (0..0x110000) |i| {
        const codepoint: u21 = @intCast(i);

        var bytes: [4]u8 = undefined;
        const encoder_len = std.unicode.utf8Encode(codepoint, &bytes) catch |err| switch (err) {
            error.Utf8CannotEncodeSurrogateHalf => continue, // Tested later
            error.CodepointTooLarge => unreachable,
        };

        const point, const len = decodeBytes(&bytes);

        try std.testing.expectEqual(encoder_len, len.toLen());
        try std.testing.expectEqual(codepoint, point);
    }
}

test "decodeBytes surrogates" {
    for (0xD800..0xDFFF) |i| {
        const codepoint: u21 = @intCast(i);
        var bytes: [4]u8 = undefined;
        _ = std.unicode.wtf8Encode(codepoint, &bytes) catch unreachable;

        const val, const len = decodeBytes(&bytes);

        try std.testing.expectEqual(invalid_codepoint, val);
        try std.testing.expectEqual(1, len.toLen());
    }
}

test "decodeBytes crashes" {
    if (!build.slow_tests) return error.SkipZigTest;

    // Ensure nothing crashes
    for (0..std.math.maxInt(u32)) |bytes| {
        const arr = std.mem.asBytes(&@as(u32, @intCast(bytes)));
        const val, const len = decodeBytes(arr);

        try std.testing.expect(len.isValid());
        std.mem.doNotOptimizeAway(&val);
    }
}

const std = @import("std");
const build = @import("build");
const root = @import("root.zig");

const assert = std.debug.assert;
const invalid_codepoint = root.invalid_codepoint;

const CodePoint = root.CodePoint;
const CodePointLen = root.CodePointLen;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
