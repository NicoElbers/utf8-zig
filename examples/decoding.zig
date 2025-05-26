pub fn main() !void {
    {
        const string = "こんにちは";
        assert(string.len == 15);

        var decoder: utf8.Decoder = .init(string);

        assert(decoder.remainingLenght() == 5);
        assert(decoder.next().? == 'こ');

        assert(decoder.remainingLenght() == 4);
        assert(decoder.next().? == 'ん');

        assert(decoder.remainingLenght() == 3);
        assert(decoder.next().? == 'に');

        assert(decoder.remainingLenght() == 2);
        assert(decoder.next().? == 'ち');

        assert(decoder.remainingLenght() == 1);
        assert(decoder.next().? == 'は');

        assert(decoder.remainingLenght() == 0);
        assert(decoder.next() == null);
    }
    {
        const gpa = std.heap.smp_allocator;
        var decoder: utf8.Decoder = .init("Hi!⚡");

        const length = decoder.remainingLenght();

        const codepoints = try decoder.decodeRemaining(gpa);
        defer gpa.free(codepoints);

        assert(codepoints.len == length);

        const expected: []const u21 = &.{ 'H', 'i', '!', '⚡' };

        for (expected, codepoints) |exp, point|
            assert(exp == point);
    }
}

const std = @import("std");
const utf8 = @import("utf8");

const assert = std.debug.assert;
