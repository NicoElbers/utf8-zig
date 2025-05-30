const japanese_bible = @embedFile("japanese_bible.txt");
const bible = @embedFile("bible.txt");

const runs = 100;

pub fn main() !void {
    std.debug.print("English bible\n", .{});
    run(bible);

    std.debug.print("Japanese bible\n", .{});
    run(japanese_bible);
}

fn run(source: []const u8) void {
    // warmup
    for (0..5) |_| for (source) |byte| std.mem.doNotOptimizeAway(&byte);

    var timer = Timer.start() catch unreachable;

    for (0..runs) |_| {
        var decoder = utf8.Decoder.init(japanese_bible);

        while (decoder.next()) |codepoint| {
            std.mem.doNotOptimizeAway(&codepoint);
        }
    }

    const my_time = timer.read() / runs;

    timer.reset();
    for (0..runs) |_| {
        var decoder: std.unicode.Utf8Iterator = .{ .bytes = japanese_bible, .i = 0 };

        while (decoder.nextCodepoint()) |codepoint| {
            std.mem.doNotOptimizeAway(&codepoint);
        }
    }

    const std_time = timer.read() / runs;

    std.debug.print("My  time: {d} ns\n", .{my_time});
    std.debug.print("std time: {d} ns\n", .{std_time});
}

const std = @import("std");
const utf8 = @import("utf8");

const Timer = std.time.Timer;
