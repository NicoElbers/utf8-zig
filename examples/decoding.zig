pub fn main() !void {
    const utf8_string = "こんにちは";
    const invalid_string = "\xFFABC";
    {
        var decoder: utf8.Decoder = .init(utf8_string);

        try exepectEqual('こ', decoder.next());
        try exepectEqual('ん', decoder.next());
        try exepectEqual('に', decoder.next());
        try exepectEqual('ち', decoder.next());
        try exepectEqual('は', decoder.next());
        try exepectEqual(null, decoder.next());
    }
    {
        var decoder: utf8.Decoder = .init(invalid_string);

        try exepectError(error.InvalidCodePoint, decoder.nextStrict());
        try exepectEqual('A', decoder.nextStrict());
        try exepectEqual('B', decoder.nextStrict());
        try exepectEqual('C', decoder.nextStrict());
        try exepectEqual(null, decoder.nextStrict());
    }
    {
        var decoder: utf8.Decoder = .init(invalid_string);

        try exepectEqual(0xFFFD, decoder.next());
        try exepectEqual('A', decoder.next());
        try exepectEqual('B', decoder.next());
        try exepectEqual('C', decoder.next());
        try exepectEqual(null, decoder.next());
    }
}

const std = @import("std");
const utf8 = @import("utf8");

const exepectEqual = std.testing.expectEqual;
const exepectError = std.testing.expectError;
const assert = std.debug.assert;
