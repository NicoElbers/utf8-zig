//! A modified version of `std.unicode.Utf8Iterator` made to not crash.
//!
//! This is not a fully correct implementation, more meant as a point of
//! reference.

const StdIterator = @This();

bytes: []const u8,
idx: usize,

pub fn init(bytes: []const u8) StdIterator {
    return .{
        .bytes = bytes,
        .idx = 0,
    };
}

pub fn next(it: *StdIterator) !?u21 {
    if (it.idx >= it.bytes.len) {
        return null;
    }

    const cp_len = std.unicode.utf8ByteSequenceLength(it.bytes[it.idx]) catch |err| {
        it.idx += 1;
        return err;
    };
    assert(cp_len > 0);

    if (it.idx + cp_len >= it.bytes.len) {
        it.idx += 1;
        return error.IncompleteCodepoint;
    }
    it.idx += cp_len;

    const slice = it.bytes[it.idx - cp_len .. it.idx];
    return try std.unicode.utf8Decode(slice);
}

const std = @import("std");

const assert = std.debug.assert;
