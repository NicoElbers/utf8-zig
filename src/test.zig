test "All possible codepoints" {
    var buf: [5]u8 = .{ undefined, undefined, undefined, undefined, 'A' };

    for (0..std.math.maxInt(u32) + 1) |int| {
        @memcpy(buf[0..4], std.mem.asBytes(&@as(u32, @intCast(int))));

        var decoder: Decoder = .init(&buf);

        var last_point: u21 = 0;
        while (decoder.next()) |point| {
            last_point = point;
        }

        // Ensure we're still in a valid state
        try std.testing.expectEqual('A', last_point);
    }
}

const std = @import("std");

const Decoder = @import("Decoder.zig");
