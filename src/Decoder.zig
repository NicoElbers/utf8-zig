//! UTF8 decoder
//!
//! This implementation works on slices until the zig IO rewrite happens.
//!
//! This implementation has 1 known bug wrt handling replacement of invalid
//! characters. Read the source for info.

source: []const u8,
curr: usize = 0,

const Decoder = @This();

pub const empty: Decoder = .{ .source = &.{} };

pub fn init(source: []const u8) Decoder {
    return .{ .source = source };
}

pub const Error = error{ IncompleteCodePoint, InvalidCodePoint };

pub fn next(self: *Decoder) ?CodePoint {
    return self.nextStrict() catch invalid_codepoint;
}

pub fn nextIgnore(self: *Decoder) ?CodePoint {
    while (true) {
        return self.nextStrict() catch continue;
    }
}

pub fn nextStrict(self: *Decoder) Error!?CodePoint {
    if (self.curr >= self.source.len) {
        @branchHint(.unlikely);
        return null;
    }

    const Length = enum {
        len1,
        len2,
        len3,
        len4,
        surrogate3_low,
        surrogate3_high,
        surrogate4_low,
        surrogate4_high,
        reject,

        const Length = @This();

        pub const l1: Length = .len1;
        pub const l2: Length = .len2;
        pub const l3: Length = .len3;
        pub const l4: Length = .len4;
        pub const s3l: Length = .surrogate3_low;
        pub const s3h: Length = .surrogate3_high;
        pub const s4l: Length = .surrogate4_low;
        pub const s4h: Length = .surrogate4_high;
        pub const re: Length = .reject;
    };

    // Map all byte values to their length.
    //
    // There are 5 special cases here.
    // 0xC0 is mapped to reject instead of len 2 as this is an overlong point
    // 0xE0 is mapped to s3l as this byte needs an additional check on it's second byte
    // 0xED is mapped to s3h as this byte needs an additional check on it's second byte
    // 0xF0 is mapped to s4l as this byte needs an additional check on it's second byte
    // 0xF4 is mapped to s4h as this byte needs an additional check on it's second byte
    const lengths: [256]Length = .{
        // ASCII, len 1
        .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, // 0x00 ... 0x0F
        .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, // 0x10 ... 0x1F
        .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, // 0x20 ... 0x2F
        .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, // 0x30 ... 0x3F
        .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, // 0x40 ... 0x4F
        .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, // 0x50 ... 0x5F
        .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, // 0x60 ... 0x6F
        .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, .l1, // 0x70 ... 0x7F

        // Continuations
        .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, // 0x80 ... 0x8F
        .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, // 0x90 ... 0x9F
        .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, // 0xA0 ... 0xAF
        .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, // 0xB0 ... 0xBF

        // len 2
        .re, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, // 0xC0 ... 0xCF
        .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, .l2, // 0xD0 ... 0xDF

        // len 3
        .s3l, .l3, .l3, .l3, .l3, .l3, .l3, .l3, .l3, .l3, .l3, .l3, .l3, .s3h, .l3, .l3, // 0xE0 ... 0xEF

        // len 4                   Out of range codepoints
        .s4l, .l4, .l4, .l4, .s4h, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, .re, // 0xF0 ... 0xFF
    };

    const State = enum {
        need1,
        need2,
        need3,
    };

    const remaining = self.source[self.curr..];

    var codepoint: CodePoint = 0;

    self.curr += 1;
    var state: State = switch (lengths[remaining[0]]) {
        .reject => {
            @branchHint(.unlikely);
            return error.InvalidCodePoint;
        },
        .len1 => {
            return remaining[0];
        },
        .len2 => blk: {
            codepoint = remaining[0] & 0b0001_1111;
            break :blk .need1;
        },
        .len3 => blk: {
            codepoint = remaining[0] & 0b0000_1111;
            break :blk .need2;
        },
        .len4 => blk: {
            codepoint = remaining[0] & 0b0000_0111;
            break :blk .need3;
        },

        inline .surrogate3_low,
        .surrogate3_high,
        .surrogate4_low,
        .surrogate4_high,
        => |len| blk: {
            if (remaining.len < 2) {
                @branchHint(.unlikely);
                return error.IncompleteCodePoint;
            }

            const byte = remaining[1];
            switch (len) {
                .surrogate3_low => {
                    if (byte < 0b1010_0000) {
                        @branchHint(.unlikely);
                        return error.InvalidCodePoint;
                    }

                    codepoint = remaining[0] & 0b0000_1111;
                    break :blk .need2;
                },
                .surrogate3_high => {
                    if (byte > 0b1001_1111) {
                        @branchHint(.unlikely);
                        return error.InvalidCodePoint;
                    }

                    codepoint = remaining[0] & 0b0000_1111;
                    break :blk .need2;
                },
                .surrogate4_low => {
                    if (byte < 0b1001_0000) {
                        @branchHint(.unlikely);
                        return error.InvalidCodePoint;
                    }

                    codepoint = remaining[0] & 0b0000_0111;
                    break :blk .need3;
                },
                .surrogate4_high => {
                    if (byte > 0b1000_1111) {
                        @branchHint(.unlikely);
                        return error.InvalidCodePoint;
                    }

                    codepoint = remaining[0] & 0b0000_0111;
                    break :blk .need3;
                },
                else => unreachable,
            }
        },
    };

    for (remaining[1..]) |byte| {
        if (byte & 0b1100_0000 != 0b1000_0000) {
            @branchHint(.unlikely);
            return error.InvalidCodePoint;
        }

        codepoint <<= 6;
        codepoint |= byte & 0b0011_1111;
        self.curr += 1;

        state = switch (state) {
            .need1 => return codepoint,
            .need2 => .need1,
            .need3 => .need2,
        };
    }

    return error.IncompleteCodePoint;
}

test nextStrict {
    const expectEqual = std.testing.expectEqual;
    const expectError = std.testing.expectError;

    const in = "hi🙂!\xFF!";
    var utf8: Decoder = .init(in);

    try expectEqual('h', utf8.nextStrict());
    try expectEqual('i', utf8.nextStrict());
    try expectEqual('🙂', utf8.nextStrict());
    try expectEqual('!', utf8.nextStrict());
    try expectError(error.InvalidCodePoint, utf8.nextStrict());
    try expectEqual('!', utf8.nextStrict());
    try expectEqual(null, utf8.nextStrict());
    try expectEqual(null, utf8.nextStrict());
}

test "Sanity" {
    const tst = struct {
        pub fn tst(in: []const u8, out: []const u21) !void {
            var decoder: Decoder = .init(in);
            for (out) |point|
                try std.testing.expectEqual(point, decoder.nextStrict());
        }
    }.tst;

    {
        const in = "A";
        const out: []const u21 = &.{'A'};

        try tst(in, out);
    }
    {
        const in = "Ƣ";
        const out: []const u21 = &.{'Ƣ'};

        try tst(in, out);
    }
    {
        const in = "ࡡ";
        const out: []const u21 = &.{'ࡡ'};

        try tst(in, out);
    }
    {
        const in = "᳄";
        const out: []const u21 = &.{'᳄'};

        try tst(in, out);
    }
    {
        const in = "𐃍";
        const out: []const u21 = &.{'𐃍'};

        try tst(in, out);
    }
    {
        const in = "こんにちは";
        const out: []const u21 = &.{ 'こ', 'ん', 'に', 'ち', 'は' };

        try tst(in, out);
    }
}

test "All valid codepoints" {
    var buf: [4]u8 = undefined;
    for (0..0x10ffff + 1) |point| {
        const cp: CodePoint = @intCast(point);
        const len = std.unicode.utf8Encode(cp, &buf) catch |err| switch (err) {
            error.Utf8CannotEncodeSurrogateHalf => continue,
            error.CodepointTooLarge => unreachable,
        };
        var decoder: Decoder = .init(buf[0..len]);

        try std.testing.expectEqual(cp, decoder.nextStrict());
        try std.testing.expectEqual(null, decoder.nextStrict());
    }
}

test "All surrogates" {
    var bytes: [4]u8 = undefined;
    for (0xD800..0xDFFF) |surrogate| {
        const len = std.unicode.wtf8Encode(@intCast(surrogate), &bytes) catch unreachable;
        var decoder: Decoder = .init(bytes[0..len]);

        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
    }
}

test "Invalid codepoints" {
    const cont: u8 = 0b1000_0000;

    const sequences = [_][]const u8{
        // Simple
        &.{0b1100_0010}, // 2 char wo continuations
        &.{0b1110_0000}, // 3 char wo continuations
        &.{0b1111_0000}, // 4 char wo continuations

        // Invalid lengths
        &.{0b1000_0000},
        &.{0b1111_1000},
        &.{0b1111_1100},
        &.{0b1111_1110},
        &.{0b1111_1111},

        // Continuations
        &.{ 0b1110_0001, cont }, // 3 char
        &.{ 0b1111_0001, cont }, // 4 char
        &.{ 0b1111_0001, cont, cont }, // 4 char

        // Funky
        &.{0b1100_0000}, // Invalid 2 char
        &.{0b1100_0001}, // Invalid 2 char
        &.{0b1111_0101}, // Out of range
    };

    inline for (sequences) |sequence| {
        const str = sequence ++ "ABC";

        // std.debug.print("\n", .{});
        // std.debug.print("Testing: '{s}'\n", .{str});
        // std.debug.print("Testing: '{X}'\n", .{str});
        // std.debug.print("Testing: '{b}'\n", .{str});
        // std.debug.print("Byte0  : 0b{b:0>8}'\n", .{str[0]});

        var decoder: Decoder = .init(str);

        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());

        // Are we in a valid state after?
        try std.testing.expectEqual('A', decoder.nextStrict());
        try std.testing.expectEqual('B', decoder.nextStrict());
        try std.testing.expectEqual('C', decoder.nextStrict());
        try std.testing.expectEqual(null, decoder.nextStrict());
    }
}

test "Incomplete codepoints" {
    const cont: u8 = 0b1000_0000;

    const sequences = [_][]const u8{
        &.{0b1100_0010}, // 2 char

        // 3 char
        &.{0b1110_0000},
        &.{ 0b1110_0001, cont },

        // 4 char
        &.{0b1111_0000},
        &.{ 0b1111_0001, cont },
        &.{ 0b1111_0001, cont, cont },
    };

    for (sequences) |sequence| {
        const str = sequence;

        // std.debug.print("\n", .{});
        // std.debug.print("Testing: '{s}'\n", .{str});
        // std.debug.print("Testing: '{X}'\n", .{str});
        // std.debug.print("Testing: '{b}'\n", .{str});
        // std.debug.print("Byte0  : 0b{b:0>8}'\n", .{str[0]});

        var decoder: Decoder = .init(str);

        try std.testing.expectError(error.IncompleteCodePoint, decoder.nextStrict());
        try std.testing.expectEqual(null, decoder.nextStrict());
    }
}

test "Incomplete surrogates" {
    // Funny property I observed in python and rust is that if you have a 4
    // byte length 'header', 3 bytes remaining however an invalid surrogate value
    // you get 3 error values

    {
        const bytes: []const u8 = &.{ 0b1111_0000, 0b1000_0000, 0b1000_0000, 0b1000_0000 };
        var decoder: Decoder = .init(bytes);

        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectEqual(null, decoder.nextStrict());
    }
    {
        const bytes: []const u8 = &.{ 0b1111_0000, 0b1000_0000, 0b1000_0000 };
        var decoder: Decoder = .init(bytes);

        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectEqual(null, decoder.nextStrict());
    }
    {
        const bytes: []const u8 = &.{ 0b1111_0000, 0b1000_0000 };
        var decoder: Decoder = .init(bytes);

        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectEqual(null, decoder.nextStrict());
    }
    {
        const bytes: []const u8 = &.{ 0b1111_0000, 0b1000_0000 };
        var decoder: Decoder = .init(bytes);

        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectEqual(null, decoder.nextStrict());
    }
    {
        const bytes: []const u8 = &.{ 0b1110_0000, 0b1000_0000, 0b1000_0000 };
        var decoder: Decoder = .init(bytes);

        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectEqual(null, decoder.nextStrict());
    }
    {
        const bytes: []const u8 = &.{ 0b1110_0000, 0b1000_0000 };
        var decoder: Decoder = .init(bytes);

        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectEqual(null, decoder.nextStrict());
    }
}

const std = @import("std");
const root = @import("root.zig");

const assert = std.debug.assert;
const invalid_codepoint = root.invalid_codepoint;

const CodePoint = root.CodePoint;
const CodePointLen = root.CodePointLen;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
