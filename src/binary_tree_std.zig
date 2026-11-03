const std = @import("std");

/// Implementation of a standard binary tree and search
pub fn BinaryTreeStd(comptime T: type) type {
    return struct {
        pub const Node = struct {
            value: T,
            left: ?*Node = null,
            right: ?*Node = null,
        };

        pub const Tree = ?*Node;

        // Key comparisons go through these helpers because Zig slices have
        // no built-in <, >, or == operators. For []const u8, lessThan and
        // greaterThan each perform a full lexicographic walk (std.mem.order)
        // and equalTo a full byte compare (std.mem.eql) — i.e. comparisons
        // whose cost grows with the shared prefix, which is exactly the
        // regime the string-key benchmark exercises. For numeric T these
        // reduce to the plain operators, so the f32 benchmark is unchanged.
        fn lessThan(a: T, b: T) bool {
            if (T == []const u8) return std.mem.order(u8, a, b) == .lt;
            return a < b;
        }

        fn greaterThan(a: T, b: T) bool {
            if (T == []const u8) return std.mem.order(u8, a, b) == .gt;
            return a > b;
        }

        fn equalTo(a: T, b: T) bool {
            if (T == []const u8) return std.mem.eql(u8, a, b);
            return a == b;
        }

        fn order3(a: T, b: T) std.math.Order {
            if (T == []const u8) return std.mem.order(u8, a, b);
            return std.math.order(a, b);
        }

        pub fn insert(allocator: std.mem.Allocator, value: T, t: Tree) !Tree {
            if (t) |node| {
                if (lessThan(value, node.value)) {
                    node.left = try insert(allocator, value, node.left);
                } else if (greaterThan(value, node.value)) {
                    node.right = try insert(allocator, value, node.right);
                }
                return t;
            } else {
                const new_node = try allocator.create(Node);
                new_node.* = .{ .value = value };
                return new_node;
            }
        }

        pub fn member(x: T, t: Tree) bool {
            var node = t;
            while (node) |curr| {
                if (lessThan(x, curr.value)) {
                    node = curr.left;
                } else if (greaterThan(x, curr.value)) {
                    node = curr.right;
                } else {
                    return true;
                }
            }
            return false;
        }

        /// Andersson's two-way search (iterative)
        pub fn member2(x: T, t: Tree) bool {
            var node = t;
            var candidate: ?T = null;

            while (node) |curr| {
                if (lessThan(x, curr.value)) {
                    node = curr.left;
                } else {
                    candidate = curr.value;
                    node = curr.right;
                }
            }
            if (candidate) |c| {
                return equalTo(c, x);
            }
            return false;
        }

        /// Andersson's two-way search (recursive)
        pub fn member2_re(x: T, t: Tree, candidate: ?T) bool {
            if (t) |node| {
                if (!lessThan(x, node.value)) {
                    return member2_re(x, node.right, node.value);
                } else {
                    return member2_re(x, node.left, candidate);
                }
            } else {
                if (candidate) |c| {
                    return equalTo(c, x);
                }
                return false;
            }
        }

        pub fn member3(x: T, t: Tree) bool {
            var node = t;
            while (node) |curr| {
                const compare = order3(x, curr.value);
                switch (compare) {
                    .lt => node = curr.left,
                    .gt => node = curr.right,
                    .eq => return true,
                }
            }
            return false;
        }
    };
}
