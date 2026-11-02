const std = @import("std");
const builtin = @import("builtin");
const bts_std = @import("binary_tree_std.zig");
const bts_sentinel = @import("binary_tree_sentinel.zig");

fn parseNumericEnvVar(
    environ_map: anytype,
    name: []const u8,
    default_value: usize,
) usize {
    if (environ_map.get(name)) |val| {
        return std.fmt.parseInt(usize, val, 10) catch |err| {
            std.debug.print("Error: Failed to parse {s} environment variable '{s}': {}\n", .{name, val, err});
            std.process.exit(1);
        };
    }
    return default_value;
}

pub fn main(init: std.process.Init) !void {
    // STRING_KEYS=1 runs the expensive-comparison variant of the benchmark:
    // fixed-length []const u8 keys with a tunable shared prefix, instead of
    // f32 keys. This is the "two-way's last stand" experiment: where key
    // comparisons are expensive (a full lexicographic walk per test), the
    // 1991 cost model may still hold on modern hardware.
    const string_keys = parseNumericEnvVar(init.environ_map, "STRING_KEYS", 0);
    if (string_keys > 1) {
        std.debug.print("Error: STRING_KEYS must be 0 or 1\n", .{});
        std.process.exit(1);
    }
    if (string_keys == 1) {
        return runStringBenchmark(init);
    }

    const io = init.io;
    const allocator = init.arena.allocator();

    const num_iterations = parseNumericEnvVar(init.environ_map, "NUM_ITERATIONS", 10_000);
    const num_elements = parseNumericEnvVar(init.environ_map, "NUM_ELEMENTS", 5000);
    const successful_search = parseNumericEnvVar(init.environ_map, "SUCCESSFUL_SEARCH", 100);
    const balanced = parseNumericEnvVar(init.environ_map, "BALANCED", 0);

    if (num_iterations == 0 or num_elements == 0) {
        std.debug.print("Zero iterations or zero elements requested. Skipping benchmark\n", .{});
        std.process.exit(1);
    }

    if (successful_search != 0 and successful_search != 100) {
        std.debug.print("Error: SUCCESSFUL_SEARCH must be 0 or 100\n", .{});
        std.process.exit(1);
    }

    if (balanced > 1) {
        std.debug.print("Error: BALANCED must be 0 or 1\n", .{});
        std.process.exit(1);
    }

    // Hardcode a random seed for consistent results across benchmarks
    var prng = std.Random.DefaultPrng.init(0x1287ab29);
    const random = prng.random();

    const keys = try allocator.alloc(f32, num_elements);
    var seen = std.AutoHashMap(u32, void).init(allocator);
    defer seen.deinit();
    try seen.ensureTotalCapacity(@intCast(num_elements));
    var key_idx: usize = 0;
    while (key_idx < num_elements) {
        const val = random.float(f32);
        const bits: u32 = @bitCast(val);
        const gop = seen.getOrPutAssumeCapacity(bits);
        if (!gop.found_existing) {
            keys[key_idx] = val;
            key_idx += 1;
        }
    }

    const method_env = init.environ_map.get("METHOD") orelse "all";
    const run_all = std.mem.eql(u8, method_env, "all");
    const run_std = run_all or std.mem.eql(u8, method_env, "standard");
    const run_sentinel = run_all or std.mem.eql(u8, method_env, "sentinel");
    const run_two = run_all or std.mem.eql(u8, method_env, "twoway");
    const run_three = run_all or std.mem.eql(u8, method_env, "threeway");

    if (!run_std and !run_sentinel and !run_two and !run_three) {
        std.debug.print("Error: Unknown METHOD '{s}'. Expected: all, standard, sentinel, twoway, threeway\n", .{method_env});
        std.process.exit(1);
    }

    // Build the tree to benchmark search on
    const IntTreeStd = bts_std.BinaryTreeStd(f32);
    var tree_std: IntTreeStd.Tree = null;

    const IntTreeSentinel = bts_sentinel.BinaryTreeSentinel(f32);
    var tree_sentinel: ?IntTreeSentinel = null;

    if (run_sentinel) {
        tree_sentinel = try IntTreeSentinel.init(allocator);
    }

    if (balanced == 1) {
        std.mem.sort(f32, keys, {}, std.sort.asc(f32));
        if (run_std or run_two or run_three) {
            tree_std = try insertBalancedStd(allocator, keys, tree_std);
        }
        if (run_sentinel) {
            try insertBalancedSentinel(allocator, keys, &tree_sentinel.?);
        }
    } else {
        if (run_std or run_two or run_three) {
            for (keys) |key| {
                tree_std = try IntTreeStd.insert(allocator, key, tree_std);
            }
        }
        if (run_sentinel) {
            for (keys) |key| {
                try tree_sentinel.?.insert(allocator, key);
            }
        }
    }

    // Generate search queries based on successful_search percentage
    const search_keys = try generateSearchKeys(allocator, random, num_iterations, num_elements, keys, successful_search);
    defer allocator.free(search_keys);

    std.debug.print("Benchmark Results (andersson probes):\n", .{});
    std.debug.print("  Tree Size: {d}\n", .{num_elements});
    std.debug.print("  Iterations: {d}\n\n", .{num_iterations});

    // Run the benchmarks
    if (run_std) {
        var std_hash: u32 = 0;
        const std_start = std.Io.Clock.awake.now(io);
        for (search_keys) |key| {
            const found = IntTreeStd.member(key, tree_std);
            const res = if (found) @as(u32, @bitCast(key)) else 0;
            std_hash = std_hash *% 33 +% res;
        }
        const std_elapsed = std_start.untilNow(io, .awake).nanoseconds;
        std.debug.print("  Standard Search:  {d:.2} ns/op | Total: {d:.2} us (Hash: 0x{x})\n", .{
            @as(f64, @floatFromInt(std_elapsed)) / @as(f64, @floatFromInt(num_iterations)),
            @as(f64, @floatFromInt(std_elapsed)) / 1000.0,
            std_hash,
        });
    }

    if (run_sentinel) {
        var sentinel_hash: u32 = 0;
        const sentinel_start = std.Io.Clock.awake.now(io);
        for (search_keys) |key| {
            const found = tree_sentinel.?.member(key);
            const res = if (found) @as(u32, @bitCast(key)) else 0;
            sentinel_hash = sentinel_hash *% 33 +% res;
        }
        const sentinel_elapsed = sentinel_start.untilNow(io, .awake).nanoseconds;
        std.debug.print("  Sentinel Search:  {d:.2} ns/op | Total: {d:.2} us (Hash: 0x{x})\n", .{
            @as(f64, @floatFromInt(sentinel_elapsed)) / @as(f64, @floatFromInt(num_iterations)),
            @as(f64, @floatFromInt(sentinel_elapsed)) / 1000.0,
            sentinel_hash,
        });
    }

    if (run_two) {
        var two_hash: u32 = 0;
        const two_start = std.Io.Clock.awake.now(io);
        for (search_keys) |key| {
            const found = IntTreeStd.member2(key, tree_std);
            const res = if (found) @as(u32, @bitCast(key)) else 0;
            two_hash = two_hash *% 33 +% res;
        }
        const two_elapsed = two_start.untilNow(io, .awake).nanoseconds;
        std.debug.print("  Two-Way Search:   {d:.2} ns/op | Total: {d:.2} us (Hash: 0x{x})\n", .{
            @as(f64, @floatFromInt(two_elapsed)) / @as(f64, @floatFromInt(num_iterations)),
            @as(f64, @floatFromInt(two_elapsed)) / 1000.0,
            two_hash,
        });
    }

    if (run_three) {
        var three_hash: u32 = 0;
        const three_start = std.Io.Clock.awake.now(io);
        for (search_keys) |key| {
            const found = IntTreeStd.member3(key, tree_std);
            const res = if (found) @as(u32, @bitCast(key)) else 0;
            three_hash = three_hash *% 33 +% res;
        }
        const three_elapsed = three_start.untilNow(io, .awake).nanoseconds;
        std.debug.print("  Three-Way Search: {d:.2} ns/op | Total: {d:.2} us (Hash: 0x{x})\n", .{
            @as(f64, @floatFromInt(three_elapsed)) / @as(f64, @floatFromInt(num_iterations)),
            @as(f64, @floatFromInt(three_elapsed)) / 1000.0,
            three_hash,
        });
    }
}

fn insertBalancedStd(
    allocator: std.mem.Allocator,
    keys: []const f32,
    tree: bts_std.BinaryTreeStd(f32).Tree,
) !bts_std.BinaryTreeStd(f32).Tree {
    if (keys.len == 0) return tree;
    const mid = keys.len / 2;
    var new_tree = try bts_std.BinaryTreeStd(f32).insert(allocator, keys[mid], tree);
    new_tree = try insertBalancedStd(allocator, keys[0..mid], new_tree);
    new_tree = try insertBalancedStd(allocator, keys[mid + 1..], new_tree);
    return new_tree;
}

fn insertBalancedSentinel(
    allocator: std.mem.Allocator,
    keys: []const f32,
    tree: *bts_sentinel.BinaryTreeSentinel(f32),
) !void {
    if (keys.len == 0) return;
    const mid = keys.len / 2;
    try tree.insert(allocator, keys[mid]);
    try insertBalancedSentinel(allocator, keys[0..mid], tree);
    try insertBalancedSentinel(allocator, keys[mid + 1..], tree);
}

pub fn generateSearchKeys(
    allocator: std.mem.Allocator,
    random: std.Random,
    num_iterations: usize,
    num_elements: usize,
    keys: []const f32,
    successful_search: usize,
) ![]f32 {
    _ = num_elements;

    if (successful_search != 0 and successful_search != 100) {
        if (!builtin.is_test) {
            std.debug.print("Error: SUCCESSFUL_SEARCH must be 0 or 100\n", .{});
            std.process.exit(1);
        }
        return error.InvalidSuccessfulSearch;
    }

    if (keys.len == 0) {
        if (!builtin.is_test) {
            std.debug.print("Error: No keys provided to generate search probes\n", .{});
            std.process.exit(1);
        }
        return error.InvalidElementCount;
    }

    // 1. Distinct sorted keys first. Work on a copy so tree construction is unaffected.
    const s_buf = try allocator.alloc(f32, keys.len);
    defer allocator.free(s_buf);
    @memcpy(s_buf, keys);
    std.mem.sort(f32, s_buf, {}, std.sort.asc(f32));

    var n: usize = 0;
    for (s_buf) |val| {
        if (n == 0 or s_buf[n - 1] != val) {
            s_buf[n] = val;
            n += 1;
        }
    }
    const s = s_buf[0..n];

    if (n == 0 or num_iterations % n != 0) {
        if (!builtin.is_test) {
            std.debug.print("Error: NUM_ITERATIONS ({d}) must be divisible by distinct keys ({d})\n", .{ num_iterations, n });
            std.process.exit(1);
        }
        return error.IndivisibleIterations;
    }
    const r = num_iterations / n;

    const base_probes = try allocator.alloc(f32, n);
    defer allocator.free(base_probes);

    if (successful_search == 100) {
        @memcpy(base_probes, s);
    } else {
        for (0..n - 1) |i| {
            const mid_f64: f64 = (@as(f64, s[i]) + @as(f64, s[i + 1])) / 2.0;
            const probe = @as(f32, @floatCast(mid_f64));
            std.debug.assert(s[i] < probe and probe < s[i + 1]);
            base_probes[i] = probe;
        }
        const last_probe = std.math.nextAfter(f32, s[n - 1], std.math.inf(f32));
        std.debug.assert(last_probe > s[n - 1]);
        base_probes[n - 1] = last_probe;
    }

    const search_keys = try allocator.alloc(f32, num_iterations);
    errdefer allocator.free(search_keys);

    var dest_idx: usize = 0;
    for (base_probes) |probe| {
        for (0..r) |_| {
            search_keys[dest_idx] = probe;
            dest_idx += 1;
        }
    }

    // Shuffle once: Andersson's array order is unspecified; enumeration counts
    // are what must match the paper, and unshuffled repetition would create order
    // artefacts on modern hardware.
    random.shuffle(f32, search_keys);

    return search_keys;
}

test "generateSearchKeys hits contract" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();

    // Distinct keys: 5 elements
    const keys = [_]f32{ 0.1, 0.25, 0.5, 0.75, 0.9 };
    const num_iterations: usize = 20; // R = 20 / 5 = 4
    const r: usize = num_iterations / keys.len;

    const search_keys = try generateSearchKeys(allocator, random, num_iterations, keys.len, &keys, 100);
    defer allocator.free(search_keys);

    try std.testing.expectEqual(num_iterations, search_keys.len);

    for (keys) |expected_key| {
        var count: usize = 0;
        for (search_keys) |k| {
            if (k == expected_key) {
                count += 1;
            }
        }
        try std.testing.expectEqual(r, count);
    }
}

test "generateSearchKeys misses contract" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();

    // Input keys with a duplicated key (0.4 appears twice)
    const keys = [_]f32{ 0.1, 0.4, 0.7, 0.4, 0.9 };
    // Distinct sorted keys will be: [0.1, 0.4, 0.7, 0.9] -> n = 4
    const distinct_keys = [_]f32{ 0.1, 0.4, 0.7, 0.9 };
    const n = distinct_keys.len;

    const num_iterations: usize = 12; // R = 12 / 4 = 3
    const r: usize = num_iterations / n;

    const search_keys = try generateSearchKeys(allocator, random, num_iterations, keys.len, &keys, 0);
    defer allocator.free(search_keys);

    try std.testing.expectEqual(num_iterations, search_keys.len);

    // Expected base probes:
    // midpoints: (s[i] + s[i+1]) / 2 for i in 0..n-2
    // plus one probe strictly greater than s[n-1]
    var expected_probes: [4]f32 = undefined;
    for (0..n - 1) |i| {
        const mid_f64 = (@as(f64, distinct_keys[i]) + @as(f64, distinct_keys[i + 1])) / 2.0;
        const probe = @as(f32, @floatCast(mid_f64));
        // Midpoint lies strictly between its neighbours
        try std.testing.expect(distinct_keys[i] < probe);
        try std.testing.expect(probe < distinct_keys[i + 1]);
        expected_probes[i] = probe;
    }
    const last_probe = std.math.nextAfter(f32, distinct_keys[n - 1], std.math.inf(f32));
    try std.testing.expect(last_probe > distinct_keys[n - 1]);
    expected_probes[n - 1] = last_probe;

    // Assert: no probe equals any key in input (even with duplicates in input)
    for (search_keys) |probe| {
        for (keys) |key| {
            try std.testing.expect(probe != key);
        }
    }

    // Assert: distinct probes are exactly the n-1 midpoints plus one value greater than max key,
    // and each occurs exactly R times.
    for (expected_probes) |expected_probe| {
        var count: usize = 0;
        for (search_keys) |k| {
            if (k == expected_probe) {
                count += 1;
            }
        }
        try std.testing.expectEqual(r, count);
    }
}

test "generateSearchKeys error conditions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();

    const keys = [_]f32{ 0.1, 0.2, 0.3, 0.4 }; // n = 4

    // SUCCESSFUL_SEARCH=50 must fail cleanly rather than producing a probe array
    try std.testing.expectError(
        error.InvalidSuccessfulSearch,
        generateSearchKeys(allocator, random, 20, keys.len, &keys, 50),
    );

    // Non-divisible NUM_ITERATIONS (e.g. 21 is not divisible by 4) must fail cleanly
    try std.testing.expectError(
        error.IndivisibleIterations,
        generateSearchKeys(allocator, random, 21, keys.len, &keys, 100),
    );

    try std.testing.expectError(
        error.IndivisibleIterations,
        generateSearchKeys(allocator, random, 21, keys.len, &keys, 0),
    );
}

// ---------------------------------------------------------------------------
// String-key benchmark ("two-way's last stand").
//
// Same four search variants as the f32 benchmark, but with []const u8 keys:
// every relational test is a full lexicographic walk (std.mem.order), whose
// cost grows with the shared prefix. Env knobs mirror the f32 path
// (NUM_ITERATIONS, NUM_ELEMENTS, SUCCESSFUL_SEARCH, BALANCED, METHOD) plus
// two for the key shape:
//
//   KEY_LEN      total key bytes (default 64; must leave >= 8 non-prefix bytes)
//   SHARED_PREFIX  identical leading bytes across all keys (default 0)
//
// Every key shares the first SHARED_PREFIX bytes, so each comparison must
// walk them before reaching distinguishing bytes: SHARED_PREFIX is the
// comparison-cost dial. Prefix 0 should reproduce the f32 verdict (two-way
// loses); the crossover prefix where two-way starts winning is the
// headline number.
// ---------------------------------------------------------------------------

fn runStringBenchmark(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();

    const num_iterations = parseNumericEnvVar(init.environ_map, "NUM_ITERATIONS", 10_000);
    const num_elements = parseNumericEnvVar(init.environ_map, "NUM_ELEMENTS", 100_000);
    const successful_search = parseNumericEnvVar(init.environ_map, "SUCCESSFUL_SEARCH", 50);
    const balanced = parseNumericEnvVar(init.environ_map, "BALANCED", 0);
    const key_len = parseNumericEnvVar(init.environ_map, "KEY_LEN", 64);
    const shared_prefix = parseNumericEnvVar(init.environ_map, "SHARED_PREFIX", 0);

    if (num_iterations == 0 or num_elements == 0) {
        std.debug.print("Zero iterations or zero elements requested. Skipping benchmark\n", .{});
        std.process.exit(1);
    }

    if (successful_search > 100) {
        std.debug.print("Error: SUCCESSFUL_SEARCH must be between 0 and 100 percent\n", .{});
        std.process.exit(1);
    }

    if (balanced > 1) {
        std.debug.print("Error: BALANCED must be 0 or 1\n", .{});
        std.process.exit(1);
    }

    if (key_len < 16 or shared_prefix + 8 > key_len) {
        std.debug.print("Error: KEY_LEN must be >= 16 with at least 8 non-prefix bytes (KEY_LEN - SHARED_PREFIX >= 8)\n", .{});
        std.process.exit(1);
    }

    // Hardcode a random seed for consistent results across benchmarks
    var prng = std.Random.DefaultPrng.init(0x1287ab29);
    const random = prng.random();

    // One prefix shared by every key: comparisons must walk it before
    // reaching bytes that distinguish keys.
    const prefix = try allocator.alloc(u8, shared_prefix);
    random.bytes(prefix);

    const keys = try allocator.alloc([]const u8, num_elements);
    for (keys) |*key| {
        const buf = try allocator.alloc(u8, key_len);
        @memcpy(buf[0..shared_prefix], prefix);
        random.bytes(buf[shared_prefix..]);
        key.* = buf;
    }

    const method_env = init.environ_map.get("METHOD") orelse "all";
    const run_all = std.mem.eql(u8, method_env, "all");
    const run_std = run_all or std.mem.eql(u8, method_env, "standard");
    const run_sentinel = run_all or std.mem.eql(u8, method_env, "sentinel");
    const run_two = run_all or std.mem.eql(u8, method_env, "twoway");
    const run_three = run_all or std.mem.eql(u8, method_env, "threeway");

    if (!run_std and !run_sentinel and !run_two and !run_three) {
        std.debug.print("Error: Unknown METHOD '{s}'. Expected: all, standard, sentinel, twoway, threeway\n", .{method_env});
        std.process.exit(1);
    }

    // Build the tree to benchmark search on
    const StrTreeStd = bts_std.BinaryTreeStd([]const u8);
    var tree_std: StrTreeStd.Tree = null;

    const StrTreeSentinel = bts_sentinel.BinaryTreeSentinel([]const u8);
    var tree_sentinel: ?StrTreeSentinel = null;

    if (run_sentinel) {
        tree_sentinel = try StrTreeSentinel.init(allocator);
    }

    if (balanced == 1) {
        std.mem.sort([]const u8, keys, {}, stringLessThan);
        if (run_std or run_two or run_three) {
            tree_std = try insertBalancedStdStr(allocator, keys, tree_std);
        }
        if (run_sentinel) {
            try insertBalancedSentinelStr(allocator, keys, &tree_sentinel.?);
        }
    } else {
        if (run_std or run_two or run_three) {
            for (keys) |key| {
                tree_std = try StrTreeStd.insert(allocator, key, tree_std);
            }
        }
        if (run_sentinel) {
            for (keys) |key| {
                try tree_sentinel.?.insert(allocator, key);
            }
        }
    }

    // Generate search queries based on successful_search percentage
    const search_keys = try generateStringSearchKeys(allocator, random, num_iterations, keys, successful_search, key_len);
    defer allocator.free(search_keys);

    // Untimed agreement check: the selected variants must return identical
    // results on every search key. This replaces the f32 path's
    // hash-the-key-bits trick — hashing 64 key bytes per hit inside the
    // timed loop would cost as much as the searches themselves and swamp
    // the numbers we are measuring. The timed loops below therefore only
    // accumulate the hit count (which feeds the printed hash exactly like
    // the f32 path and still pins the compiler from DCE-ing the search).
    for (search_keys) |key| {
        var expected: ?bool = null;
        if (run_std) checkAgreement(&expected, StrTreeStd.member(key, tree_std));
        if (run_sentinel) checkAgreement(&expected, tree_sentinel.?.member(key));
        if (run_two) checkAgreement(&expected, StrTreeStd.member2(key, tree_std));
        if (run_three) checkAgreement(&expected, StrTreeStd.member3(key, tree_std));
    }

    std.debug.print("Benchmark Results (string keys):\n", .{});
    std.debug.print("  Tree Size: {d}\n", .{num_elements});
    std.debug.print("  Iterations: {d}\n", .{num_iterations});
    std.debug.print("  Key Length: {d}\n", .{key_len});
    std.debug.print("  Shared Prefix: {d}\n\n", .{shared_prefix});

    // Run the benchmarks
    if (run_std) {
        var std_hash: u32 = 0;
        const std_start = std.Io.Clock.awake.now(io);
        for (search_keys) |key| {
            const found = StrTreeStd.member(key, tree_std);
            const res: u32 = if (found) 1 else 0;
            std_hash = std_hash *% 33 +% res;
        }
        const std_elapsed = std_start.untilNow(io, .awake).nanoseconds;
        std.debug.print("  Standard Search:  {d:.2} ns/op | Total: {d:.2} us (Hash: 0x{x})\n", .{
            @as(f64, @floatFromInt(std_elapsed)) / @as(f64, @floatFromInt(num_iterations)),
            @as(f64, @floatFromInt(std_elapsed)) / 1000.0,
            std_hash,
        });
    }

    if (run_sentinel) {
        var sentinel_hash: u32 = 0;
        const sentinel_start = std.Io.Clock.awake.now(io);
        for (search_keys) |key| {
            const found = tree_sentinel.?.member(key);
            const res: u32 = if (found) 1 else 0;
            sentinel_hash = sentinel_hash *% 33 +% res;
        }
        const sentinel_elapsed = sentinel_start.untilNow(io, .awake).nanoseconds;
        std.debug.print("  Sentinel Search:  {d:.2} ns/op | Total: {d:.2} us (Hash: 0x{x})\n", .{
            @as(f64, @floatFromInt(sentinel_elapsed)) / @as(f64, @floatFromInt(num_iterations)),
            @as(f64, @floatFromInt(sentinel_elapsed)) / 1000.0,
            sentinel_hash,
        });
    }

    if (run_two) {
        var two_hash: u32 = 0;
        const two_start = std.Io.Clock.awake.now(io);
        for (search_keys) |key| {
            const found = StrTreeStd.member2(key, tree_std);
            const res: u32 = if (found) 1 else 0;
            two_hash = two_hash *% 33 +% res;
        }
        const two_elapsed = two_start.untilNow(io, .awake).nanoseconds;
        std.debug.print("  Two-Way Search:   {d:.2} ns/op | Total: {d:.2} us (Hash: 0x{x})\n", .{
            @as(f64, @floatFromInt(two_elapsed)) / @as(f64, @floatFromInt(num_iterations)),
            @as(f64, @floatFromInt(two_elapsed)) / 1000.0,
            two_hash,
        });
    }

    if (run_three) {
        var three_hash: u32 = 0;
        const three_start = std.Io.Clock.awake.now(io);
        for (search_keys) |key| {
            const found = StrTreeStd.member3(key, tree_std);
            const res: u32 = if (found) 1 else 0;
            three_hash = three_hash *% 33 +% res;
        }
        const three_elapsed = three_start.untilNow(io, .awake).nanoseconds;
        std.debug.print("  Three-Way Search: {d:.2} ns/op | Total: {d:.2} us (Hash: 0x{x})\n", .{
            @as(f64, @floatFromInt(three_elapsed)) / @as(f64, @floatFromInt(num_iterations)),
            @as(f64, @floatFromInt(three_elapsed)) / 1000.0,
            three_hash,
        });
    }
}

fn checkAgreement(expected: *?bool, got: bool) void {
    if (expected.*) |e| {
        if (e != got) {
            std.debug.print("Error: search variants disagree on a key\n", .{});
            std.process.exit(1);
        }
    } else {
        expected.* = got;
    }
}

fn stringLessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == .lt;
}

fn insertBalancedStdStr(
    allocator: std.mem.Allocator,
    keys: []const []const u8,
    tree: bts_std.BinaryTreeStd([]const u8).Tree,
) !bts_std.BinaryTreeStd([]const u8).Tree {
    if (keys.len == 0) return tree;
    const mid = keys.len / 2;
    var new_tree = try bts_std.BinaryTreeStd([]const u8).insert(allocator, keys[mid], tree);
    new_tree = try insertBalancedStdStr(allocator, keys[0..mid], new_tree);
    new_tree = try insertBalancedStdStr(allocator, keys[mid + 1..], new_tree);
    return new_tree;
}

fn insertBalancedSentinelStr(
    allocator: std.mem.Allocator,
    keys: []const []const u8,
    tree: *bts_sentinel.BinaryTreeSentinel([]const u8),
) !void {
    if (keys.len == 0) return;
    const mid = keys.len / 2;
    try tree.insert(allocator, keys[mid]);
    try insertBalancedSentinelStr(allocator, keys[0..mid], tree);
    try insertBalancedSentinelStr(allocator, keys[mid + 1..], tree);
}

pub fn generateStringSearchKeys(
    allocator: std.mem.Allocator,
    random: std.Random,
    num_iterations: usize,
    keys: []const []const u8,
    successful_search: usize,
    key_len: usize,
) ![][]const u8 {
    const search_keys = try allocator.alloc([]const u8, num_iterations);
    errdefer allocator.free(search_keys);
    for (search_keys) |*key| {
        if (random.intRangeLessThan(usize, 0, 100) < successful_search) {
            key.* = keys[random.intRangeLessThan(usize, 0, keys.len)];
        } else {
            // Miss: copy a real key and flip its last byte. The result
            // shares the prefix and almost all of the tail with a real
            // key, so failed comparisons walk nearly the whole key —
            // the most expensive miss possible — while (with >= 8
            // random tail bytes) never colliding with a real key in
            // practice.
            const src = keys[random.intRangeLessThan(usize, 0, keys.len)];
            const buf = try allocator.alloc(u8, key_len);
            @memcpy(buf, src);
            buf[key_len - 1] ^= 0xff;
            key.* = buf;
        }
    }
    return search_keys;
}

test "generateStringSearchKeys ratio verification" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var prng = std.Random.DefaultPrng.init(0);
    const random = prng.random();

    const key_len = 32;
    const keys = try allocator.alloc([]const u8, 10);
    for (keys) |*k| {
        const buf = try allocator.alloc(u8, key_len);
        random.bytes(buf);
        k.* = buf;
    }

    const contains = struct {
        fn f(haystack: []const []const u8, needle: []const u8) bool {
            for (haystack) |k| {
                if (std.mem.eql(u8, k, needle)) return true;
            }
            return false;
        }
    }.f;

    // 100% hits: every search key is a tree key
    {
        const search_keys = try generateStringSearchKeys(allocator, random, 1000, keys, 100, key_len);
        defer allocator.free(search_keys);

        var hit_count: usize = 0;
        for (search_keys) |k| {
            if (contains(keys, k)) hit_count += 1;
        }
        try std.testing.expectEqual(@as(usize, 1000), hit_count);
    }

    // 0% hits: no search key is a tree key, and every miss shares all but
    // its last byte with some real key (maximal shared prefix)
    {
        const search_keys = try generateStringSearchKeys(allocator, random, 1000, keys, 0, key_len);
        defer allocator.free(search_keys);

        for (search_keys) |k| {
            try std.testing.expect(!contains(keys, k));
            try std.testing.expectEqual(key_len, k.len);
            var shares_prefix = false;
            for (keys) |real| {
                if (std.mem.eql(u8, real[0 .. key_len - 1], k[0 .. key_len - 1])) {
                    shares_prefix = true;
                    break;
                }
            }
            try std.testing.expect(shares_prefix);
        }
    }

    // 50% hits
    {
        const search_keys = try generateStringSearchKeys(allocator, random, 1000, keys, 50, key_len);
        defer allocator.free(search_keys);

        var hit_count: usize = 0;
        for (search_keys) |k| {
            if (contains(keys, k)) hit_count += 1;
        }
        try std.testing.expect(hit_count >= 450 and hit_count <= 550);
    }
}
