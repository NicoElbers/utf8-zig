const japanese_bible = @embedFile("japanese_bible.txt");
const bible = @embedFile("bible.txt");

pub fn main() !void {
    std.debug.print("English bible\n", .{});
    run(bible);

    std.debug.print("Japanese bible\n", .{});
    run(japanese_bible);
}

const seconds = 5;
fn run(source: []const u8) void {
    // warmup
    for (0..5) |_| for (source) |byte| std.mem.doNotOptimizeAway(&byte);

    {
        var timer = Timer.start() catch unreachable;
        var runs: usize = 0;
        var errors: usize = 0;
        while (timer.read() < std.time.ns_per_s * seconds) {
            var decoder = utf8.Decoder.init(source);

            while (decoder.nextStrict() catch {
                errors += 1;
                continue;
            }) |codepoint| {
                std.mem.doNotOptimizeAway(&codepoint);
            }

            runs += 1;
        }
        const time: f64 = @floatFromInt(timer.read());

        const total_bytes: f64 = @floatFromInt(source.len * runs);

        std.debug.print("Mine strict\n", .{});
        std.debug.print("{d} runs in {d:.2} sec\n", .{ runs, time / std.time.ns_per_s });
        std.debug.print("{d} errors ({d})\n", .{ errors, errors / runs });
        std.debug.print("{d: >6.2} MB/s\n\n", .{(total_bytes / 1_000_000) / (time / std.time.ns_per_s)});
    }
    {
        var timer = Timer.start() catch unreachable;
        var runs: usize = 0;
        while (timer.read() < std.time.ns_per_s * seconds) {
            var decoder = utf8.Decoder.init(source);

            while (decoder.next()) |codepoint| {
                std.mem.doNotOptimizeAway(&codepoint);
            }

            runs += 1;
        }
        const time: f64 = @floatFromInt(timer.read());

        const total_bytes: f64 = @floatFromInt(source.len * runs);

        std.debug.print("Mine replace\n", .{});
        std.debug.print("{d} runs in {d:.2} sec\n", .{ runs, time / std.time.ns_per_s });
        std.debug.print("{d: >6.2} MB/s\n\n", .{(total_bytes / 1_000_000) / (time / std.time.ns_per_s)});
    }
    {
        var timer = Timer.start() catch unreachable;
        var runs: usize = 0;
        while (timer.read() < std.time.ns_per_s * seconds) {
            var decoder = utf8.Decoder.init(source);

            while (decoder.nextIgnore()) |codepoint| {
                std.mem.doNotOptimizeAway(&codepoint);
            }

            runs += 1;
        }
        const time: f64 = @floatFromInt(timer.read());

        const total_bytes: f64 = @floatFromInt(source.len * runs);

        std.debug.print("Mine ignore\n", .{});
        std.debug.print("{d} runs in {d:.2} sec\n", .{ runs, time / std.time.ns_per_s });
        std.debug.print("{d: >6.2} MB/s\n\n", .{(total_bytes / 1_000_000) / (time / std.time.ns_per_s)});
    }
    {
        var timer = Timer.start() catch unreachable;
        var runs: usize = 0;
        while (timer.read() < std.time.ns_per_s * seconds) {
            var decoder = utf8.Decoder.init(source);

            while (decoder.next()) |codepoint| {
                std.mem.doNotOptimizeAway(&codepoint);
            }

            runs += 1;
        }
        const time: f64 = @floatFromInt(timer.read());

        const total_bytes: f64 = @floatFromInt(source.len * runs);

        std.debug.print("Std\n", .{});
        std.debug.print("{d} runs in {d:.2} sec\n", .{ runs, time / std.time.ns_per_s });
        std.debug.print("{d: >6.2} MB/s\n\n", .{(total_bytes / 1_000_000) / (time / std.time.ns_per_s)});
    }
    {
        var timer = Timer.start() catch unreachable;
        var runs: usize = 0;
        while (timer.read() < std.time.ns_per_s * seconds) {
            var decoder: StdIterator = .{ .bytes = source };

            while (decoder.next()) |codepoint| {
                std.mem.doNotOptimizeAway(&codepoint);
            }

            runs += 1;
        }
        const time: f64 = @floatFromInt(timer.read());

        const total_bytes: f64 = @floatFromInt(source.len * runs);

        std.debug.print("Std modified\n", .{});
        std.debug.print("{d} runs in {d:.2} sec\n", .{ runs, time / std.time.ns_per_s });
        std.debug.print("{d: >6.2} MB/s\n\n", .{(total_bytes / 1_000_000) / (time / std.time.ns_per_s)});
    }
}

const std = @import("std");
const utf8 = @import("utf8");

const Timer = std.time.Timer;

const StdIterator = struct {
    bytes: []const u8,
    curr: usize = 0,

    pub fn init(bytes: []const u8) StdIterator {
        return .{ .bytes = bytes };
    }

    pub fn nextSlice(it: *StdIterator) !?[]const u8 {
        if (it.curr >= it.bytes.len) {
            return null;
        }

        const cp_len = try std.unicode.utf8ByteSequenceLength(it.bytes[it.curr]);
        it.curr += cp_len;
        return it.bytes[it.curr - cp_len .. it.curr];
    }

    pub fn next(it: *StdIterator) ?u21 {
        const slice = blk: {
            if (it.curr >= it.bytes.len) {
                return null;
            }

            const cp_len = std.unicode.utf8ByteSequenceLength(it.bytes[it.curr]) catch {
                it.curr += 1;
                return 0xFFFD;
            };

            it.curr += cp_len;
            break :blk it.bytes[it.curr - cp_len .. it.curr];
        };
        return std.unicode.utf8Decode(slice) catch 0xFFFD;
    }
};
