const Run = struct {
    name: []const u8,
    data_bytes: usize,
    runs: usize,
    min_ms: f64,
    p05_ms: f64,
    p25_ms: f64,
    p50_ms: f64,
    p75_ms: f64,
    p95_ms: f64,
    max_ms: f64,
};

const Spin = struct {
    time_ns: u64,
    bytes: u64,
    errors: u64,
    hash: u21,
};

const TestCase = struct { name: []const u8, run: []const Run };

const timeout = 1;

const cases = [_]struct { *const fn ([]const u21) Spin, []const u8 }{
    .{ mineSpin, "utf8-zig" },
    // .{ mineSpin2, "utf8-zig 2" },
};

pub fn main() !void {
    var dbg_inst = std.heap.DebugAllocator(.{}).init;
    defer _ = dbg_inst.deinit();
    var arena_inst = std.heap.ArenaAllocator.init(dbg_inst.allocator());
    defer arena_inst.deinit();
    const arena = arena_inst.allocator();

    var tests = std.ArrayListUnmanaged(TestCase).empty;

    var prng = Random.DefaultPrng.init(0xbadc0de);
    const r = prng.random();

    var buf: [1024 * 1024]u21 = undefined;
    {
        std.debug.print("Valid len 1 codepoints\n", .{});
        for (&buf) |*point|
            point.* = validCodePointLen1(r);

        try tests.append(arena, .{ .name = "len 1 codepoints", .run = runAll(&buf, arena) });
    }
    {
        std.debug.print("Valid len 2 codepoints\n", .{});
        for (&buf) |*point|
            point.* = validCodePointLen2(r);

        try tests.append(arena, .{ .name = "len 2 codepoints", .run = runAll(&buf, arena) });
    }
    {
        std.debug.print("Valid len 3 codepoints\n", .{});
        for (&buf) |*point|
            point.* = validCodePointLen3(r);

        try tests.append(arena, .{ .name = "len 3 codepoints", .run = runAll(&buf, arena) });
    }
    {
        std.debug.print("Valid len 4 codepoints\n", .{});
        for (&buf) |*point|
            point.* = validCodePointLen4(r);

        try tests.append(arena, .{ .name = "len 4 codepoints", .run = runAll(&buf, arena) });
    }
    {
        std.debug.print("Valid codepoints\n", .{});
        for (&buf) |*point|
            point.* = validCodePoint(r);

        try tests.append(arena, .{ .name = "Valid codepoints", .run = runAll(&buf, arena) });
    }
    {
        std.debug.print("Invalid codepoints\n", .{});
        for (&buf) |*point|
            point.* = invalidCodePoint(r);
        try tests.append(arena, .{ .name = "Invalid codepoints", .run = runAll(&buf, arena) });
    }
    {
        std.debug.print("Mixed codepoints\n", .{});
        for (&buf) |*point|
            point.* = uniformCodePoint(r);
        try tests.append(arena, .{ .name = "Mixed codepoints", .run = runAll(&buf, arena) });
    }
    {
        std.debug.print("Mostly valid codepoints\n", .{});
        for (&buf) |*point|
            point.* = mostlyValidCodePoints(r);
        try tests.append(arena, .{ .name = "Mostly valid codepoints", .run = runAll(&buf, arena) });
    }

    const stdout = std.io.getStdOut().writer();
    try std.json.stringify(tests.items, .{}, stdout);
}

pub fn runAll(source: []const u21, alloc: Allocator) []Run {
    const runs = alloc.alloc(Run, cases.len) catch @panic("OOM");
    inline for (runs, &cases) |*run, case| {
        run.* = runOne(case.@"0", case.@"1", source);
    }

    return runs;
}

pub fn runOne(comptime func: *const fn ([]const u21) Spin, name: []const u8, source: []const u21) Run {
    var runs: [5_000]Spin = undefined;

    var timer = std.time.Timer.start() catch unreachable;
    for (&runs, 1..) |*item, i| {
        item.* = func(source);

        if (timer.read() > std.time.ns_per_s * timeout) {
            return format(name, source, runs[0..i]);
        }
    } else return format(name, source, &runs);
}

fn format(name: []const u8, source: []const u21, runs: []Spin) Run {
    std.mem.sort(Spin, runs, {}, struct {
        pub fn lessThanFn(_: void, a: Spin, b: Spin) bool {
            return a.time_ns < b.time_ns;
        }
    }.lessThanFn);

    for (runs) |r| assert(r.bytes == runs[0].bytes);
    for (runs) |r| assert(r.errors == runs[0].errors);
    for (runs) |r| assert(r.hash == runs[0].hash);

    const p00: f64 = @floatFromInt(runs[0].time_ns);
    const p05: f64 = @floatFromInt(runs[(runs.len / 100) * 5].time_ns);
    const p25: f64 = @floatFromInt(runs[runs.len / 4].time_ns);
    const p50: f64 = @floatFromInt(runs[runs.len / 2].time_ns);
    const p75: f64 = @floatFromInt(runs[(runs.len / 4) * 3].time_ns);
    const p95: f64 = @floatFromInt(runs[(runs.len / 100) * 95].time_ns);
    const p100: f64 = @floatFromInt(runs[runs.len - 1].time_ns);

    const mb: f64 = @as(f64, @floatFromInt(source.len)) / 1_000_000;

    std.debug.print(
        \\  {s}:
        \\    bytes: {d}
        \\    errors: {d}
        \\    runs: {d}
        \\    min : {d: >7.3} ms; {d: >7.3} MB/s
        \\    p05 : {d: >7.3} ms; {d: >7.3} MB/s
        \\    p25 : {d: >7.3} ms; {d: >7.3} MB/s
        \\    p50 : {d: >7.3} ms; {d: >7.3} MB/s
        \\    p75 : {d: >7.3} ms; {d: >7.3} MB/s
        \\    p95 : {d: >7.3} ms; {d: >7.3} MB/s
        \\    max : {d: >7.3} ms; {d: >7.3} MB/s
        \\
        \\
    , .{
        name,                      runs[0].bytes,
        runs[0].errors,            runs.len,
        p00 / std.time.ns_per_ms,  mb / (p00 / std.time.ns_per_s),
        p05 / std.time.ns_per_ms,  mb / (p05 / std.time.ns_per_s),
        p25 / std.time.ns_per_ms,  mb / (p25 / std.time.ns_per_s),
        p50 / std.time.ns_per_ms,  mb / (p50 / std.time.ns_per_s),
        p75 / std.time.ns_per_ms,  mb / (p75 / std.time.ns_per_s),
        p95 / std.time.ns_per_ms,  mb / (p95 / std.time.ns_per_s),
        p100 / std.time.ns_per_ms, mb / (p100 / std.time.ns_per_s),
    });

    return .{
        .data_bytes = source.len,
        .name = name,
        .runs = runs.len,
        .min_ms = p00 / std.time.ns_per_ms,
        .p05_ms = p05 / std.time.ns_per_ms,
        .p25_ms = p25 / std.time.ns_per_ms,
        .p50_ms = p50 / std.time.ns_per_ms,
        .p75_ms = p75 / std.time.ns_per_ms,
        .p95_ms = p95 / std.time.ns_per_ms,
        .max_ms = p100 / std.time.ns_per_ms,
    };
}

fn mineSpin(source: []const u21) Spin {
    var bytes: usize = 0;
    var errors: usize = 0;
    var hash: u21 = 0;

    var buf: [4]u8 = undefined;
    var timer = std.time.Timer.start() catch unreachable;
    for (source) |point| {
        const encoded = utf8.encodeStrict(point, &buf) catch {
            errors += 1;
            continue;
        };

        bytes += encoded.len;
        hash ^= encoded[0];
    }
    const time = timer.read();

    return .{
        .time_ns = time,
        .bytes = bytes,
        .errors = errors,
        .hash = hash,
    };
}

fn mineSpin2(source: []const u21) Spin {
    var bytes: usize = 0;
    var errors: usize = 0;
    var hash: u21 = 0;

    var buf: [4]u8 = undefined;
    var timer = std.time.Timer.start() catch unreachable;
    for (source) |point| {
        const encoded = utf8.encodeStrict2(point, &buf) catch {
            errors += 1;
            continue;
        };

        bytes += encoded.len;
        hash ^= encoded[0];
    }
    const time = timer.read();

    return .{
        .time_ns = time,
        .bytes = bytes,
        .errors = errors,
        .hash = hash,
    };
}

fn validCodePointLen1(r: Random) u21 {
    return r.int(u7);
}

fn validCodePointLen2(r: Random) u21 {
    return r.intRangeAtMost(u21, 0x80, 0x7FF);
}

fn validCodePointLen3(r: Random) u21 {
    return r.intRangeAtMost(u21, 0x800, 0xFFFF);
}

fn validCodePointLen4(r: Random) u21 {
    return r.intRangeAtMost(u21, 0x10000, 0x10FFFF);
}

fn invalidCodePoint(r: Random) u21 {
    return r.intRangeAtMost(u21, 0x110000, std.math.maxInt(u21));
}

fn validCodePoint(r: Random) u21 {
    const Type = enum { len1, len2, len3, len4 };
    return switch (r.enumValue(Type)) {
        .len1 => validCodePointLen1(r),
        .len2 => validCodePointLen1(r),
        .len3 => validCodePointLen1(r),
        .len4 => validCodePointLen1(r),
    };
}

fn uniformCodePoint(r: Random) u21 {
    const Type = enum { len1, len2, len3, len4, invalid };
    return switch (r.enumValue(Type)) {
        .len1 => validCodePointLen1(r),
        .len2 => validCodePointLen1(r),
        .len3 => validCodePointLen1(r),
        .len4 => validCodePointLen1(r),
        .invalid => invalidCodePoint(r),
    };
}

/// Produces 99% valid and 1% invalid codepoints
fn mostlyValidCodePoints(r: Random) u21 {
    return switch (r.weightedIndex(u32, &.{ 99, 1 })) {
        0 => validCodePoint(r),
        1 => invalidCodePoint(r),
        else => unreachable,
    };
}

const std = @import("std");
const utf8 = @import("utf8");

const assert = std.debug.assert;

const Random = std.Random;
const Allocator = std.mem.Allocator;
