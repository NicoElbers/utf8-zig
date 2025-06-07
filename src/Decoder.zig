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

/// Get the next codepoint, returning an error on invalid codepoints
pub fn nextStrict(self: *Decoder) Error!?CodePoint {
    if (self.curr >= self.source.len) {
        @branchHint(.unlikely);
        return null;
    }

    const s: []const u8 = self.source[self.curr..];

    // NOTE: When directly returning instead of doing this trick performance
    // tanks by 30% - 90% (wtf LLVM)
    const codepoint: CodePoint =
        if (s[0] <= 0b0111_1111) blk: {
            self.curr += 1;

            break :blk s[0];
        } else if (s[0] & 0b1110_0000 == 0b1100_0000) blk: {
            if (s[0] < 0b1100_0010) {
                @branchHint(.unlikely);
                self.curr += 1;
                return error.InvalidCodePoint;
            }

            if (s.len < 2) {
                @branchHint(.unlikely);
                self.parseContinuations(s[1..]);
                self.curr += 1;
                return error.IncompleteCodePoint;
            }

            if (s[1] & 0b1100_0000 != 0b1000_0000) {
                @branchHint(.unlikely);
                self.parseContinuations(s[1..][0..1]);
                self.curr += 1;
                return error.InvalidCodePoint;
            }

            self.curr += 2;

            break :blk @as(CodePoint, s[0] & 0b0001_1111) << 6 |
                @as(CodePoint, s[1] & 0b0011_1111) << 0;
        } else if (s[0] & 0b1111_0000 == 0b1110_0000) blk: {
            if (s.len < 3) {
                @branchHint(.unlikely);

                // Little bit of trickery to optimize the happy path while
                // retaining correct behavior
                if (s.len < 2) {
                    @branchHint(.unlikely);

                    self.parseContinuations(s[1..]);
                    self.curr += 1;
                    return error.IncompleteCodePoint;
                }

                if (s[0] == 0b1110_0000 and s[1] < 0b1010_0000) {
                    @branchHint(.unlikely);
                    self.curr += 1;
                    return error.InvalidCodePoint;
                }

                if (s[0] == 0b1110_1101 and s[1] > 0b1001_1111) {
                    @branchHint(.unlikely);
                    self.curr += 1;
                    return error.InvalidCodePoint;
                }

                self.parseContinuations(s[1..]);
                self.curr += 1;
                return error.IncompleteCodePoint;
            }

            if (s[0] == 0b1110_0000 and s[1] < 0b1010_0000) {
                @branchHint(.unlikely);
                self.curr += 1;
                return error.InvalidCodePoint;
            }

            if (s[0] == 0b1110_1101 and s[1] > 0b1001_1111) {
                @branchHint(.unlikely);
                self.curr += 1;
                return error.InvalidCodePoint;
            }

            if (s[1] & 0b1100_0000 != 0b1000_0000 or
                s[2] & 0b1100_0000 != 0b1000_0000)
            {
                @branchHint(.unlikely);
                self.parseContinuations(s[1..][0..2]);
                self.curr += 1;
                return error.InvalidCodePoint;
            }

            self.curr += 3;

            break :blk @as(CodePoint, s[0] & 0b0000_1111) << 12 |
                @as(CodePoint, s[1] & 0b0011_1111) << 6 |
                @as(CodePoint, s[2] & 0b0011_1111) << 0;
        } else if (s[0] & 0b1111_1000 == 0b1111_0000) blk: {
            if (s[0] > 0b1111_0100) {
                @branchHint(.unlikely);
                self.curr += 1;
                return error.InvalidCodePoint;
            }

            if (s.len < 4) {
                @branchHint(.unlikely);

                // Little bit of trickery to optimize the happy path while
                // retaining correct behavior
                if (s.len < 2) {
                    @branchHint(.unlikely);
                    self.parseContinuations(s[1..]);
                    self.curr += 1;
                    return error.IncompleteCodePoint;
                }

                if (s[0] == 0b1111_0000 and s[1] < 0b1001_0000) {
                    @branchHint(.unlikely);
                    self.curr += 1;
                    return error.InvalidCodePoint;
                }

                if (s[0] == 0b1111_0100 and s[1] > 0b1000_1111) {
                    @branchHint(.unlikely);
                    self.curr += 1;
                    return error.InvalidCodePoint;
                }

                self.parseContinuations(s[1..]);
                self.curr += 1;
                return error.IncompleteCodePoint;
            }

            if (s[0] == 0b1111_0000 and s[1] < 0b1001_0000) {
                @branchHint(.unlikely);
                self.curr += 1;
                return error.InvalidCodePoint;
            }

            if (s[0] == 0b1111_0100 and s[1] > 0b1000_1111) {
                @branchHint(.unlikely);
                self.curr += 1;
                return error.InvalidCodePoint;
            }

            if (s[1] & 0b1100_0000 != 0b1000_0000 or
                s[2] & 0b1100_0000 != 0b1000_0000 or
                s[3] & 0b1100_0000 != 0b1000_0000)
            {
                @branchHint(.unlikely);
                self.parseContinuations(s[1..][0..3]);
                self.curr += 1;
                return error.InvalidCodePoint;
            }

            self.curr += 4;

            break :blk @as(CodePoint, s[0] & 0b0000_0111) << 18 |
                @as(CodePoint, s[1] & 0b0011_1111) << 12 |
                @as(CodePoint, s[2] & 0b0011_1111) << 6 |
                @as(CodePoint, s[3] & 0b0011_1111) << 0;
        } else {
            @branchHint(.unlikely);
            self.curr += 1;
            return error.InvalidCodePoint;
        };

    return codepoint;
}

/// Takes a slice of potential continuations, adds the amount of
/// valid continuations from self.curr
///
/// Asserts the size of the slice is < 4
fn parseContinuations(self: *Decoder, slice: []const u8) void {
    assert(slice.len < 4); // With a slice of 4 we can always get a codepoint

    switch (slice.len) {
        0 => {},
        1 => {
            if (slice[0] & 0b1100_0000 == 0b1000_0000) self.curr += 1 else return;
        },
        2 => {
            if (slice[0] & 0b1100_0000 == 0b1000_0000) self.curr += 1 else return;
            if (slice[1] & 0b1100_0000 == 0b1000_0000) self.curr += 1 else return;
        },
        3 => {
            if (slice[0] & 0b1100_0000 == 0b1000_0000) self.curr += 1 else return;
            if (slice[1] & 0b1100_0000 == 0b1000_0000) self.curr += 1 else return;
            if (slice[2] & 0b1100_0000 == 0b1000_0000) self.curr += 1 else return;
        },
        else => unreachable,
    }
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

        // No continuations
        &.{0b1100_0010},
        &.{0b1110_0000},
        &.{0b1111_0000},

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

test "Boundaries" {
    {
        var decoder: Decoder = .init(&.{ 0b1100_0000, 0b1000_0000, 'A' });

        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectEqual('A', decoder.nextStrict());
        try std.testing.expectEqual(null, decoder.nextStrict());
    }
    {
        var decoder: Decoder = .init(&.{ 0b1100_0001, 0b1000_0000, 'A' });

        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectEqual('A', decoder.nextStrict());
        try std.testing.expectEqual(null, decoder.nextStrict());
    }
    {
        var decoder: Decoder = .init(&.{ 0b1111_0101, 0b1000_0000, 0b1000_0000, 0b1000_0000, 'A' });

        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectError(error.InvalidCodePoint, decoder.nextStrict());
        try std.testing.expectEqual('A', decoder.nextStrict());
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
}

const std = @import("std");
const root = @import("root.zig");

const assert = std.debug.assert;
const invalid_codepoint = root.invalid_codepoint;

const CodePoint = root.CodePoint;
const CodePointLen = root.CodePointLen;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
