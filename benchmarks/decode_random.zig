pub fn main() !void {
    var dbg_inst = std.heap.DebugAllocator(.{}).init;
    const gpa = dbg_inst.allocator();

    std.debug.print("Valid\n", .{});
    try runValid(gpa);
    std.debug.print("Invalid\n", .{});
    try runInvalid(gpa);
}

fn validChar(r: Random) utf8.CodePoint {
    // Doesn't have to be efficient
    while (true) {
        const cp = r.intRangeAtMost(u21, 0, 0x1FFFFF);

        if (!std.unicode.utf8ValidCodepoint(cp))
            continue;

        return cp;
    }
}

const size = 8 * 1024 * 1024;
const seconds = 5;

fn validChars(r: Random, gpa: Allocator) ![]const u8 {
    var arr: std.ArrayListUnmanaged(u8) = .empty;
    defer arr.deinit(gpa);

    var buf: [4]u8 = undefined;
    while (arr.items.len < size) {
        const cp = validChar(r);

        const len = std.unicode.utf8Encode(cp, &buf) catch unreachable;

        try arr.appendSlice(gpa, buf[0..len]);
    }

    return arr.toOwnedSlice(gpa);
}

fn runValid(gpa: Allocator) !void {
    var prng = std.Random.DefaultPrng.init(0xdeadbeef);
    const random = prng.random();

    const buf = try validChars(random, gpa);
    defer gpa.free(buf);

    // Warmup
    for (0..5) |_| for (buf) |byte| std.mem.doNotOptimizeAway(&byte);

    {
        var runs: usize = 0;
        var errors: usize = 0;
        var timer = Timer.start() catch unreachable;
        while (timer.read() < seconds * std.time.ns_per_s) {
            runs += 1;
            var decoder = MyDecoder.init(buf);

            while (decoder.nextStrict() catch {
                errors += 1;
                continue;
            }) |point| {
                std.mem.doNotOptimizeAway(&point);
            }
        }
        const time = timer.read();
        const time_f: f64 = @floatFromInt(time);
        const total_bytes: f64 = @floatFromInt(buf.len * runs);

        std.debug.print("Decoder strict\n", .{});
        std.debug.print("{d} errors\n", .{errors});
        std.debug.print("{d} runs over {d:.2} seconds\n", .{ runs, time_f / std.time.ns_per_s });
        std.debug.print("{d: >6.2} MB/s\n\n", .{(total_bytes / 1_000_000) / (time_f / std.time.ns_per_s)});
    }
    {
        var runs: usize = 0;
        var timer = Timer.start() catch unreachable;
        while (timer.read() < seconds * std.time.ns_per_s) {
            runs += 1;
            var decoder = MyDecoder.init(buf);

            while (decoder.next()) |point| {
                std.mem.doNotOptimizeAway(&point);
            }
        }
        const time = timer.read();
        const time_f: f64 = @floatFromInt(time);
        const total_bytes: f64 = @floatFromInt(buf.len * runs);

        std.debug.print("Decoder replace\n", .{});
        std.debug.print("{d} runs over {d:.2} seconds\n", .{ runs, time_f / std.time.ns_per_s });
        std.debug.print("{d: >6.2} MB/s\n\n", .{(total_bytes / 1_000_000) / (time_f / std.time.ns_per_s)});
    }
    {
        var runs: usize = 0;
        var timer = Timer.start() catch unreachable;
        while (timer.read() < seconds * std.time.ns_per_s) {
            runs += 1;
            var decoder = MyDecoder.init(buf);

            while (decoder.nextIgnore()) |point| {
                std.mem.doNotOptimizeAway(&point);
            }
        }
        const time = timer.read();
        const time_f: f64 = @floatFromInt(time);
        const total_bytes: f64 = @floatFromInt(buf.len * runs);

        std.debug.print("Decoder ignore\n", .{});
        std.debug.print("{d} runs over {d:.2} seconds\n", .{ runs, time_f / std.time.ns_per_s });
        std.debug.print("{d: >6.2} MB/s\n\n", .{(total_bytes / 1_000_000) / (time_f / std.time.ns_per_s)});
    }
    {
        var runs: usize = 0;
        var timer = Timer.start() catch unreachable;
        while (timer.read() < seconds * std.time.ns_per_s) {
            runs += 1;
            var decoder = StdIterator.init(buf);

            while (decoder.next()) |point| {
                std.mem.doNotOptimizeAway(&point);
            }
        }
        const time = timer.read();
        const time_f: f64 = @floatFromInt(time);
        const total_bytes: f64 = @floatFromInt(buf.len * runs);

        std.debug.print("Std modified\n", .{});
        std.debug.print("{d} runs over {d:.2} seconds\n", .{ runs, time_f / std.time.ns_per_s });
        std.debug.print("{d: >6.2} MB/s\n\n", .{(total_bytes / 1_000_000) / (time_f / std.time.ns_per_s)});
    }
}

fn runInvalid(gpa: Allocator) !void {
    var prng = std.Random.DefaultPrng.init(0xdeadbeef);
    const random = prng.random();

    const buf = try gpa.alloc(u8, size);
    defer gpa.free(buf);

    random.bytes(buf);

    // Warmup
    for (0..5) |_| for (buf) |byte| std.mem.doNotOptimizeAway(&byte);

    {
        var runs: usize = 0;
        var errors: usize = 0;
        var timer = Timer.start() catch unreachable;
        while (timer.read() < seconds * std.time.ns_per_s) {
            runs += 1;
            var decoder = MyDecoder.init(buf);

            while (decoder.nextStrict() catch {
                errors += 1;
                continue;
            }) |point| {
                std.mem.doNotOptimizeAway(&point);
            }
        }
        const time = timer.read();
        const time_f: f64 = @floatFromInt(time);
        const total_bytes: f64 = @floatFromInt(buf.len * runs);

        std.debug.print("Decoder strict\n", .{});
        std.debug.print("{d} errors\n", .{errors});
        std.debug.print("{d} runs over {d:.2} seconds\n", .{ runs, time_f / std.time.ns_per_s });
        std.debug.print("{d: >6.2} MB/s\n\n", .{(total_bytes / 1_000_000) / (time_f / std.time.ns_per_s)});
    }
    {
        var runs: usize = 0;
        var timer = Timer.start() catch unreachable;
        while (timer.read() < seconds * std.time.ns_per_s) {
            runs += 1;
            var decoder = MyDecoder.init(buf);

            while (decoder.next()) |point| {
                std.mem.doNotOptimizeAway(&point);
            }
        }
        const time = timer.read();
        const time_f: f64 = @floatFromInt(time);
        const total_bytes: f64 = @floatFromInt(buf.len * runs);

        std.debug.print("Decoder replace\n", .{});
        std.debug.print("{d} runs over {d:.2} seconds\n", .{ runs, time_f / std.time.ns_per_s });
        std.debug.print("{d: >6.2} MB/s\n\n", .{(total_bytes / 1_000_000) / (time_f / std.time.ns_per_s)});
    }
    {
        var runs: usize = 0;
        var timer = Timer.start() catch unreachable;
        while (timer.read() < seconds * std.time.ns_per_s) {
            runs += 1;
            var decoder = MyDecoder.init(buf);

            while (decoder.nextIgnore()) |point| {
                std.mem.doNotOptimizeAway(&point);
            }
        }
        const time = timer.read();
        const time_f: f64 = @floatFromInt(time);
        const total_bytes: f64 = @floatFromInt(buf.len * runs);

        std.debug.print("Decoder ignore\n", .{});
        std.debug.print("{d} runs over {d:.2} seconds\n", .{ runs, time_f / std.time.ns_per_s });
        std.debug.print("{d: >6.2} MB/s\n\n", .{(total_bytes / 1_000_000) / (time_f / std.time.ns_per_s)});
    }
    {
        var runs: usize = 0;
        var timer = Timer.start() catch unreachable;
        while (timer.read() < seconds * std.time.ns_per_s) {
            runs += 1;
            var decoder = StdIterator.init(buf);

            while (decoder.next()) |point| {
                std.mem.doNotOptimizeAway(&point);
            }
        }
        const time = timer.read();
        const time_f: f64 = @floatFromInt(time);
        const total_bytes: f64 = @floatFromInt(buf.len * runs);

        std.debug.print("Std modified\n", .{});
        std.debug.print("{d} runs over {d:.2} seconds\n", .{ runs, time_f / std.time.ns_per_s });
        std.debug.print("{d: >6.2} MB/s\n\n", .{(total_bytes / 1_000_000) / (time_f / std.time.ns_per_s)});
    }
}

const std = @import("std");
const utf8 = @import("utf8");

const MyDecoder = utf8.Decoder;
const StdDecoder = std.unicode.Utf8Iterator;
const Allocator = std.mem.Allocator;
const Timer = std.time.Timer;
const Random = std.Random;

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

            if ((it.curr + cp_len) > it.bytes.len) {
                return null;
            }

            it.curr += cp_len;
            break :blk it.bytes[it.curr - cp_len .. it.curr];
        };
        return std.unicode.utf8Decode(slice) catch 0xFFFD;
    }
};
