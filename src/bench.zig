const std = @import("std");

pub const BenchmarkStats = struct {
    count: f64 = 0,
    mean: f64 = 0,
    m2: f64 = 0,
    min: u64 = std.math.maxInt(u64),
    max: u64 = 0,
    hash: u32 = 0,
    elapsed_ns: u64 = 0,

    const This = @This();

    /// Record hash value only (useful for the un-timed warm-up phase)
    pub fn recordHash(self: *This, hash_val: u32) void {
        self.hash = self.hash *% 33 +% hash_val;
    }

    /// Record a timed sample and the associated step hash value
    pub fn record(self: *This, sample: u64, hash_val: u32) void {
        self.min = @min(self.min, sample);
        self.max = @max(self.max, sample);
        self.recordHash(hash_val);

        const x = @as(f64, @floatFromInt(sample));
        self.count += 1.0;

        const delta = x - self.mean;
        self.mean += delta / self.count;

        const delta2 = x - self.mean;
        self.m2 += delta * delta2;
    }

    /// Returns the unbiased sample variance
    pub fn variance(self: *This) f64 {
        if (self.count < 2.0) return 0.0;
        return self.m2 / (self.count - 1.0);
    }

    /// Returns the standard deviation
    pub fn standard_deviation(self: *This) f64 {
        return std.math.sqrt(self.variance());
    }
};

pub fn runBenchmark(
    comptime KeyType: type,
    io: std.Io,
    keys: []const KeyType,
    bench: anytype,
) BenchmarkStats {
    var stats = BenchmarkStats{};

    // 1. Warm-up (un-timed, accumulates hash only)
    const warm_up_limit = @min(100, keys.len);
    for (keys[0..warm_up_limit]) |key| {
        stats.recordHash(bench.run(key));
    }

    // 2. Timed loop with online stats
    const start_time = std.Io.Clock.awake.now(io);

    for (keys) |key| {
        const step_start = std.Io.Clock.awake.now(io);
        const res = bench.run(key);
        const step_elapsed = step_start.untilNow(io, .awake);

        stats.record(@intCast(step_elapsed.nanoseconds), res);
    }

    const elapsed = start_time.untilNow(io, .awake);
    stats.elapsed_ns = @intCast(elapsed.nanoseconds);

    return stats;
}

test "BenchmarkStats basic operations" {
    var stats = BenchmarkStats{};

    stats.record(10, 100);
    stats.record(20, 200);
    stats.record(30, 300);

    try std.testing.expectEqual(@as(u64, 10), stats.min);
    try std.testing.expectEqual(@as(u64, 30), stats.max);
    
    try std.testing.expectApproxEqAbs(@as(f64, 20.0), stats.mean, 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 10.0), stats.standard_deviation(), 1e-9);
}
