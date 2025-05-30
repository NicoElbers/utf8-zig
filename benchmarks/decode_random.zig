pub fn main() !void {
    var dbg_inst = std.heap.DebugAllocator(.{}).init;
    const gpa = dbg_inst.allocator();

    var records: [20]u64 = undefined;

    const runs = 1_000;
    inline for (&records, 5..) |*record, log2| {
        const size = 1 << log2;
        const time: u64 = try run(size, runs, gpa);
        const time_f: f64 = @floatFromInt(time);
        record.* = time;

        const byte_per_ns = size / time_f;
        const mb_per_s = 1000 * byte_per_ns;

        std.debug.print(
            "size: {d: >8}; time: {d: >10.3}us; MB/s: {d: >10.2}\n",
            .{ size, time_f / std.time.ns_per_us, mb_per_s },
        );
    }
}

fn run(size: usize, runs: usize, gpa: Allocator) !u64 {
    var prng = std.Random.DefaultPrng.init(0xdeadbeef);
    const random = prng.random();

    const buf = try gpa.alloc(u8, size);
    defer gpa.free(buf);

    random.bytes(buf);

    // Warmup
    for (0..5) |_| for (buf) |byte| std.mem.doNotOptimizeAway(&byte);

    var timer = Timer.start() catch unreachable;

    for (0..runs) |_| {
        var decoder = MyDecoder.init(buf);

        while (decoder.next()) |point| {
            std.mem.doNotOptimizeAway(&point);
        }
    }

    return timer.read() / runs;
}

const std = @import("std");
const utf8 = @import("utf8");

const MyDecoder = utf8.Decoder;
const StdDecoder = std.unicode.Utf8Iterator;
const Allocator = std.mem.Allocator;
const Timer = std.time.Timer;
