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
    if (self.curr >= self.source.len) return null;
    const remaining = self.source[self.curr..];

    const len: CodePointLen = .parse(remaining[0]);

    if (!len.isValid()) {
        @branchHint(.unlikely);
        self.curr += 1;
        return error.InvalidCodePoint;
    }

    // BUG: This is incorrect. If we have a broken surrogate this should turn
    // into a single invalid character.
    // Test case:
    //   &.{ 0b1111_0000, 0b1001_0000, 0b1000_0000 }
    // Should ouput (verified through python and rust)
    //   &.{ error }
    // Outputs
    //   &.{ error, error, error }
    // This will be much easier to fix once I integrate this with a reader, and
    // I only want to do that once we have good buffered readers (IO rewrite).
    if (remaining.len < len.toLen()) {
        @branchHint(.unlikely);
        self.curr += 1;
        return error.IncompleteCodePoint;
    }

    return switch (len) {
        .@"1" => blk: {
            self.curr += 1;
            break :blk remaining[0];
        },
        .@"2" => blk: {
            const bytes = remaining[0..2];

            if (bytes[0] < 0b1100_0010 or // Non cannonical
                bytes[1] & 0b1100_0000 != 0b1000_0000) // continuation
            {
                @branchHint(.unlikely);
                self.curr += 1;
                return error.InvalidCodePoint;
            }

            var codepoint: CodePoint = bytes[0] & 0b0001_1111;
            codepoint <<= 6;
            codepoint |= bytes[1] & 0b0011_1111;

            self.curr += 2;
            break :blk codepoint;
        },
        .@"3" => blk: {
            const bytes = remaining[0..3];

            // Surrogate
            if ((bytes[0] == 0b1110_0000 and bytes[1] < 0b1010_0000) or
                (bytes[0] == 0b1110_1101 and bytes[1] > 0b10011111))
            {
                @branchHint(.unlikely);
                self.curr += 1;
                return error.InvalidCodePoint;
            }

            // Continuations
            if (bytes[1] & 0b1100_0000 != 0b1000_0000) {
                @branchHint(.unlikely);
                self.curr += 1;
                return error.InvalidCodePoint;
            }

            if (bytes[2] & 0b1100_0000 != 0b1000_0000) {
                @branchHint(.unlikely);
                self.curr += 2;
                return error.InvalidCodePoint;
            }

            var codepoint: CodePoint = bytes[0] & 0b0000_1111;
            codepoint <<= 6;
            codepoint |= bytes[1] & 0b0011_1111;
            codepoint <<= 6;
            codepoint |= bytes[2] & 0b0011_1111;

            self.curr += 3;
            break :blk codepoint;
        },
        .@"4" => blk: {
            const bytes = remaining[0..4];

            // Range
            if (bytes[0] > 0b1111_0100) {
                @branchHint(.unlikely);
                self.curr += 1;
                return error.InvalidCodePoint;
            }

            // Surrogate
            if ((bytes[0] == 0b1111_0000 and bytes[1] < 0b1001_0000) or
                (bytes[0] == 0b1111_0100 and bytes[1] > 0b1000_1111))
            {
                @branchHint(.unlikely);
                self.curr += 1;
                return error.InvalidCodePoint;
            }

            // Continuations
            if (bytes[1] & 0b1100_0000 != 0b1000_0000) // Cont
            {
                @branchHint(.unlikely);
                self.curr += 1;
                return error.InvalidCodePoint;
            }

            if (bytes[2] & 0b1100_0000 != 0b1000_0000) {
                @branchHint(.unlikely);
                self.curr += 2;
                return error.InvalidCodePoint;
            }

            if (bytes[3] & 0b1100_0000 != 0b1000_0000) {
                @branchHint(.unlikely);
                self.curr += 3;
                return error.InvalidCodePoint;
            }

            var codepoint: CodePoint = bytes[0] & 0b0000_0111;
            codepoint <<= 6;
            codepoint |= bytes[1] & 0b0011_1111;
            codepoint <<= 6;
            codepoint |= bytes[2] & 0b0011_1111;
            codepoint <<= 6;
            codepoint |= bytes[3] & 0b0011_1111;

            self.curr += 4;
            break :blk codepoint;
        },
        else => unreachable,
    };
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

test "Invalid characters" {
    const cont: u8 = 0b1000_0000;
    _ = &cont;

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

const std = @import("std");
const root = @import("root.zig");

const assert = std.debug.assert;
const invalid_codepoint = root.invalid_codepoint;

const CodePoint = root.CodePoint;
const CodePointLen = root.CodePointLen;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
