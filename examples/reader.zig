pub fn main() !void {
    const gpa = std.heap.smp_allocator;

    var args = std.process.args();
    const arg0 = args.next().?;

    const path = args.next() orelse {
        std.log.err("Usage {s} [file]", .{arg0});
        std.process.exit(1);
    };

    const file = if (std.fs.path.isAbsolute(path))
        try std.fs.openFileAbsoluteZ(path, .{})
    else
        try std.fs.cwd().openFileZ(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(gpa, std.math.maxInt(usize));
    defer gpa.free(content);

    var decoder: Decoder = .init(content);
    var codepoints: usize = 0;
    var errors: usize = 0;
    var hash: u21 = 0;

    var timer = std.time.Timer.start() catch unreachable;
    while (true) {
        const point = decoder.nextStrict() catch {
            errors += 1;
            continue;
        } orelse break;
        codepoints += 1;
        hash ^= point;
    }
    const time: f64 = @as(f64, @floatFromInt(timer.read()));

    std.log.info(
        \\{d} codepoints 
        \\{d} errors
        \\hash: {d}
        \\Took {d: >6.5}ms ({d: >6.2} MB/s)
    , .{
        codepoints,
        errors,
        hash,
        time / std.time.ns_per_ms,
        (@as(f64, @floatFromInt(content.len)) / (1024 * 1024)) / (time / std.time.ns_per_s),
    });
}

const utf8 = @import("utf8");
const std = @import("std");

const Decoder = utf8.Decoder;
