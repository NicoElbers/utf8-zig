pub fn main() !void {
    {
        var buf: [4]u8 = undefined;
        const codepoint: []const u8 = utf8.encode('🚀', &buf);

        // Characters are put inside the provided buffer
        assert(&buf == codepoint.ptr);

        // 🚀 is a 4 byte character, so our returned slice will be 4 bytes
        assert(codepoint.len == 4);

        // The encoded values of 🚀 are:
        assert(codepoint[0] == 0xF0);
        assert(codepoint[1] == 0x9F);
        assert(codepoint[2] == 0x9A);
        assert(codepoint[3] == 0x80);
    }

    {
        var buf: [4]u8 = undefined;
        // maxInt(u21) is an invalid codepoint
        const codepoint: []const u8 = utf8.encode(std.math.maxInt(u21), &buf);
        assert(&buf == codepoint.ptr);

        var buf2: [4]u8 = undefined;
        const invalid: []const u8 = utf8.encode(utf8.invalid_codepoint, &buf2);

        // Invalid codepoints get treated as `0xFFFD`
        assert(std.mem.eql(u8, codepoint, invalid));
    }
}

const utf8 = @import("utf8");
const std = @import("std");

const assert = std.debug.assert;
