pub fn main() !void {
    const string = "こんにちは";
    assert(string.len == 15);

    var decoder: utf8.Decoder = .init(string);

    try exepectEqual('こ', decoder.next());
    try exepectEqual('ん', decoder.next());
    try exepectEqual('に', decoder.next());
    try exepectEqual('ち', decoder.next());
    try exepectEqual('は', decoder.next());
    try exepectEqual(null, decoder.next());
}

const std = @import("std");
const utf8 = @import("utf8");

const exepectEqual = std.testing.expectEqual;
const assert = std.debug.assert;
