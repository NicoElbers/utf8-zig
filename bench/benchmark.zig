const japanese_bible = @embedFile("japanese_bible.txt");

const Run = struct {
    name: []const u8,
    data_bytes: usize,
    runs: usize,
    min_ms: f64,
    p25_ms: f64,
    p50_ms: f64,
    p75_ms: f64,
    p95_ms: f64,
    max_ms: f64,
};

const Spin = struct {
    time_ns: u64,
    codepoints: u64,
    errors: u64,
    hash: u32,
};

const TestCase = struct { name: []const u8, run: []const Run };

const timeout = 10;

fn randomCodePointLen1(r: Random) [1]u8 {
    return .{r.int(u7)};
}
fn randomCodePointLen2(r: Random) [2]u8 {
    const len: u8 = 0b1100_0000 | @as(u8, r.int(u5));
    const cont1: u8 = 0b1000_0000 | @as(u8, r.int(u6));

    return .{ len, cont1 };
}
fn randomCodePointLen3(r: Random) [3]u8 {
    while (true) {
        const len: u8 = 0b1110_0000 | @as(u8, r.int(u4));
        const cont1: u8 = 0b1000_0000 | @as(u8, r.int(u6));
        const cont2: u8 = 0b1000_0000 | @as(u8, r.int(u6));

        if (len == 0b1110_0000 and cont1 < 0b1010_0000)
            continue;

        if (len == 0b1110_1101 and cont1 > 0b1001_1111)
            continue;

        return .{ len, cont1, cont2 };
    }
}
fn randomCodePointLen4(r: Random) [4]u8 {
    while (true) {
        const len: u8 = 0b1111_0000 | @as(u8, r.int(u3));
        const cont1: u8 = 0b1000_0000 | @as(u8, r.int(u6));
        const cont2: u8 = 0b1000_0000 | @as(u8, r.int(u6));
        const cont3: u8 = 0b1000_0000 | @as(u8, r.int(u6));

        if (len > 0b11110100)
            continue;

        if (len == 0b1111_0000 and cont1 < 0b1001_0000)
            continue;

        if (len == 0b1111_0100 and cont1 > 0b1000_1111)
            continue;

        return .{ len, cont1, cont2, cont3 };
    }
}

fn randomCodePoint(r: Random, ret: *[4]u8) usize {
    const Len = enum { len1, len2, len3, len4 };

    const len = r.enumValue(Len);

    return switch (len) {
        .len1 => {
            const cp = randomCodePointLen1(r);
            @memcpy(ret[0..1], &cp);
            return 1;
        },
        .len2 => {
            const cp = randomCodePointLen2(r);
            @memcpy(ret[0..2], &cp);
            return 2;
        },
        .len3 => {
            const cp = randomCodePointLen3(r);
            @memcpy(ret[0..3], &cp);
            return 3;
        },
        .len4 => {
            const cp = randomCodePointLen4(r);
            @memcpy(ret[0..4], &cp);
            return 4;
        },
    };
}

pub fn main() !void {
    var dbg_inst = std.heap.DebugAllocator(.{}).init;
    defer _ = dbg_inst.deinit();
    const gpa = dbg_inst.allocator();

    var tests = std.ArrayListUnmanaged(TestCase).empty;
    defer tests.deinit(gpa);

    std.debug.print("\njapanese bible: ({d} bytes)\n", .{japanese_bible.len});
    try tests.append(gpa, .{ .name = "japanese bible", .run = &runAll(japanese_bible) });

    // 2 MB
    var buf: [2 * 1024 * 1024]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0xbadc0de);
    const rand = prng.random();
    {
        var i: usize = 0;
        while (i < buf.len) {
            const cp = randomCodePointLen1(rand);
            @memcpy(buf[i .. i + 1], &cp);
            i += 1;
        }

        std.debug.print("\nrandom Len 1 bytes: ({d} bytes)\n", .{i});
        try tests.append(gpa, .{ .name = "random len 1 characters", .run = &runAll(&buf) });
    }
    {
        var i: usize = 0;
        while (i < buf.len - 2) {
            const cp = randomCodePointLen2(rand);
            @memcpy(buf[i .. i + 2], &cp);
            i += 2;
        }

        std.debug.print("\nrandom Len 2 bytes: ({d} bytes)\n", .{i});
        try tests.append(gpa, .{ .name = "random len 2 characters", .run = &runAll(buf[0..i]) });
    }
    {
        var i: usize = 0;
        while (i < buf.len - 3) {
            const cp = randomCodePointLen3(rand);
            @memcpy(buf[i .. i + 3], &cp);
            i += 3;
        }

        std.debug.print("\nrandom Len 3 bytes: ({d} bytes)\n", .{i});
        try tests.append(gpa, .{ .name = "random len 3 characters", .run = &runAll(buf[0..i]) });
    }
    {
        var i: usize = 0;
        while (i < buf.len - 4) {
            const cp = randomCodePointLen4(rand);
            @memcpy(buf[i .. i + 4], &cp);
            i += 4;
        }

        std.debug.print("\nrandom Len 4 bytes: ({d} bytes)\n", .{i});
        try tests.append(gpa, .{ .name = "random len 4 characters", .run = &runAll(buf[0..i]) });
    }
    {
        var i: usize = 0;
        while (i < buf.len - 4) {
            const len = randomCodePoint(rand, buf[0..4]);
            i += len;
        }

        std.debug.print("\nrandom utf8: ({d} bytes)\n", .{i});
        try tests.append(gpa, .{ .name = "random UTF8 characters", .run = &runAll(buf[0..i]) });
    }
    {
        var i: usize = 0;
        while (i < buf.len - 4) {
            i += std.unicode.wtf8Encode(rand.int(u21), buf[i .. i + 4]) catch continue;
        }

        std.debug.print("\nrandom wtf8 bytes: ({d} bytes)\n", .{i});
        try tests.append(gpa, .{ .name = "random WTF8 characters", .run = &runAll(buf[0..i]) });
    }

    const writer = std.io.getStdOut().writer();
    try std.json.stringify(tests.items, .{}, writer);
}

const cases = [_]struct { *const fn ([]const u8) Spin, []const u8 }{
    .{ mineSpin, "utf8-zig" },
    .{ stdIteratorSpin, "std fixed" },
    .{ hoehrmannSpin, "hoehrmann" },
    .{ wellonsSpin, "wellons" },
};

fn runAll(source: []const u8) [cases.len]Run {
    var res: [cases.len]Run = undefined;

    inline for (cases, 0..) |case, i| {
        res[i] = runOne(case.@"0", case.@"1", timeout, source);
    }

    return res;
}

fn runOne(comptime func: *const fn ([]const u8) Spin, name: []const u8, timeout_s: u64, source: []const u8) Run {
    var runs: [5_000]Spin = undefined;

    var timer = std.time.Timer.start() catch unreachable;
    for (&runs, 1..) |*item, i| {
        item.* = func(source);

        if (timer.read() > std.time.ns_per_s * timeout_s) {
            return format(name, source, runs[0..i]);
        }
    } else return format(name, source, &runs);
}

fn format(name: []const u8, source: []const u8, runs: []Spin) Run {
    std.mem.sort(Spin, runs, {}, struct {
        pub fn lessThanFn(_: void, a: Spin, b: Spin) bool {
            return a.time_ns < b.time_ns;
        }
    }.lessThanFn);

    for (runs) |r| assert(r.codepoints == runs[0].codepoints);
    for (runs) |r| assert(r.errors == runs[0].errors);
    for (runs) |r| assert(r.hash == runs[0].hash);

    const p00: f64 = @floatFromInt(runs[0].time_ns);
    const p25: f64 = @floatFromInt(runs[runs.len / 4].time_ns);
    const p50: f64 = @floatFromInt(runs[runs.len / 2].time_ns);
    const p75: f64 = @floatFromInt(runs[(runs.len / 4) * 3].time_ns);
    const p95: f64 = @floatFromInt(runs[(runs.len / 100) * 95].time_ns);
    const p100: f64 = @floatFromInt(runs[runs.len - 1].time_ns);

    const mb: f64 = @as(f64, @floatFromInt(source.len)) / 1_000_000;

    std.debug.print(
        \\  {s}:
        \\    codepoints: {d}
        \\    errors: {d}
        \\    runs: {d}
        \\    min : {d: >7.3} ms; {d: >7.3} MB/s
        \\    p25 : {d: >7.3} ms; {d: >7.3} MB/s
        \\    p50 : {d: >7.3} ms; {d: >7.3} MB/s
        \\    p75 : {d: >7.3} ms; {d: >7.3} MB/s
        \\    p95 : {d: >7.3} ms; {d: >7.3} MB/s
        \\    max : {d: >7.3} ms; {d: >7.3} MB/s
        \\
        \\
    , .{
        name,                      runs[0].codepoints,
        runs[0].errors,            runs.len,
        p00 / std.time.ns_per_ms,  mb / (p00 / std.time.ns_per_s),
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
        .p25_ms = p25 / std.time.ns_per_ms,
        .p50_ms = p50 / std.time.ns_per_ms,
        .p75_ms = p75 / std.time.ns_per_ms,
        .p95_ms = p95 / std.time.ns_per_ms,
        .max_ms = p100 / std.time.ns_per_ms,
    };
}

fn mineSpin(source: []const u8) Spin {
    var decoder: utf8.Decoder = .init(source);

    var points: u64 = 0;
    var errors: u64 = 0;
    var hash: u32 = 0;

    var timer = std.time.Timer.start() catch unreachable;
    while (true) {
        hash ^= decoder.nextStrict() catch {
            errors += 1;
            continue;
        } orelse break;

        points += 1;
    }
    const time = timer.read();

    return .{
        .time_ns = time,
        .codepoints = points,
        .errors = errors,
        .hash = hash,
    };
}

fn hoehrmannSpin(source: []const u8) Spin {
    const begin = source.ptr;
    const end = source.ptr + source.len;
    var points: u64 = 0;
    var errors: u64 = 0;
    var hash: u32 = 0;

    var timer = std.time.Timer.start() catch unreachable;
    hoehrmann_spin(
        begin,
        end,
        &points,
        &errors,
        &hash,
    );
    const time = timer.read();

    return .{
        .time_ns = time,
        .codepoints = points,
        .errors = errors,
        .hash = hash,
    };
}

fn wellonsSpin(source: []const u8) Spin {
    const begin = source.ptr;
    const end = source.ptr + source.len;
    var points: u64 = 0;
    var errors: u64 = 0;
    var hash: u32 = 0;

    var timer = std.time.Timer.start() catch unreachable;
    wellons_spin(
        begin,
        end,
        &points,
        &errors,
        &hash,
    );
    const time = timer.read();

    return .{
        .time_ns = time,
        .codepoints = points,
        .errors = errors,
        .hash = hash,
    };
}

fn stdIteratorSpin(source: []const u8) Spin {
    var points: u64 = 0;
    var errors: u64 = 0;
    var hash: u32 = 0;

    var decoder: StdIterator = .init(source);

    var timer = std.time.Timer.start() catch unreachable;
    while (true) {
        hash ^= decoder.next() catch {
            errors += 1;
            continue;
        } orelse break;

        points += 1;
    }
    const time = timer.read();

    return .{
        .time_ns = time,
        .codepoints = points,
        .errors = errors,
        .hash = hash,
    };
}

extern fn hoehrmann_spin(
    begin: [*]const u8,
    end: [*]const u8,
    num_codepoints: *u64,
    num_errors: *u64,
    hash: *u32,
) void;

extern fn wellons_spin(
    begin: [*]const u8,
    end: [*]const u8,
    num_codepoints: *u64,
    num_errors: *u64,
    hash: *u32,
) void;

const std = @import("std");
const utf8 = @import("utf8");
const build = @import("build");

const assert = std.debug.assert;

const Random = std.Random;

const StdIterator = struct {
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
};
