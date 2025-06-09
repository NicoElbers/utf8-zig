pub const Decoder = @import("Decoder.zig");
pub const encode = @import("encoder.zig").encode;
pub const encodeStrict = @import("encoder.zig").encodeStrict;
pub const encodeStrict2 = @import("encoder.zig").encodeStrict2;

/// Codepoint used when {en,de}coding an invalid value
pub const invalid_codepoint: CodePoint = 0xFFFD;

pub const CodePoint = u21;
pub const CodePointLen = enum(u8) {
    @"1" = 0,
    @"2" = 2,
    @"3" = 3,
    @"4" = 4,
    _,

    pub const invalid: CodePointLen = @enumFromInt(std.math.maxInt(u8));

    pub fn from(idx: u4) CodePointLen {
        return switch (idx) {
            1 => .@"1",
            2 => .@"2",
            3 => .@"3",
            4 => .@"4",
            else => unreachable,
        };
    }

    /// Sees if lhs is greater than rhs. Invalid values give an undefined result
    pub fn gte(lhs: CodePointLen, rhs: CodePointLen) bool {
        return lhs.toBits() >= rhs.toBits();
    }

    /// Converts len to the bits used for the length.
    ///
    /// Guarantees that the returned value is <= 4
    pub fn toBits(len: CodePointLen) u3 {
        return @min(@as(u3, @truncate(@intFromEnum(len))), 4);
    }

    pub fn toLen(len: CodePointLen) u3 {
        if (!len.isValid()) return 1;
        const int: u3 = @truncate(@intFromEnum(len));
        return (int -| 1) + 1;
    }

    test toLen {
        {
            // Len 1
            const len: CodePointLen = .parse(0b0111_1111);
            try std.testing.expectEqual(1, len.toLen());
        }
        {
            // Len 2
            const len: CodePointLen = .parse(0b1101_1111);
            try std.testing.expectEqual(2, len.toLen());
        }
        {
            // Len 3
            const len: CodePointLen = .parse(0b1110_1111);
            try std.testing.expectEqual(3, len.toLen());
        }
        {
            // Len 4
            const len: CodePointLen = .parse(0b1111_0111);
            try std.testing.expectEqual(4, len.toLen());
        }
        {
            // Segment
            const len: CodePointLen = .parse(0b1011_1111);
            try std.testing.expectEqual(1, len.toLen());
        }
    }

    pub fn isValid(len: CodePointLen) bool {
        const len_int = @intFromEnum(len);
        return len_int <= 4 and len_int != 1;
    }

    pub fn parse(first_byte: u8) CodePointLen {
        return @enumFromInt(@clz(~first_byte));
    }

    test parse {
        const expectEqual = std.testing.expectEqual;

        const tst = struct {
            pub fn tst(cpl: CodePointLen, byte: u8) !void {
                try expectEqual(cpl, parse(byte));
            }
        }.tst;

        // All possible ASCII values
        for (0b0000_0000..0b0111_1111 + 1) |byte| {
            try tst(.@"1", @intCast(byte));
        }

        // All possible 2 len
        for (0b1100_0000..0b1101_1111 + 1) |byte| {
            try tst(.@"2", @intCast(byte));
        }

        // All possible 3 len
        for (0b1110_0000..0b1110_1111 + 1) |byte| {
            try tst(.@"3", @intCast(byte));
        }

        // All possible 4 len
        for (0b1111_0000..0b1111_0111 + 1) |byte| {
            try tst(.@"4", @intCast(byte));
        }

        // All invalid
        const tstInvalid = struct {
            pub fn tstInvalid(byte: u8) !void {
                try std.testing.expect(!CodePointLen.parse(byte).isValid());
            }
        }.tstInvalid;

        // Invalid len: start `10`
        for (0b1000_0000..0b1011_1111 + 1) |byte| {
            try tstInvalid(@intCast(byte));
        }

        // Invalid len: start `1111_1`
        for (0b1111_1000..0b1111_1111 + 1) |byte| {
            try tstInvalid(@intCast(byte));
        }
    }
};

comptime {
    _ = CodePointLen;
    _ = Decoder;
    _ = encode;
}

const std = @import("std");
