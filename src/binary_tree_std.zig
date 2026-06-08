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

        pub fn insert(allocator: std.mem.Allocator, value: T, t: Tree) !Tree {
            if (t) |node| {
                if (value < node.value) {
                    node.left = try insert(allocator, value, node.left);
                } else if (value > node.value) {
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
                if (x < curr.value) {
                    node = curr.left;
                } else if (x > curr.value) {
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
                if (x < curr.value) {
                    node = curr.left;
                } else {
                    candidate = curr.value;
                    node = curr.right;
                }
            }
            if (candidate) |c| {
                return c == x;
            }
            return false;
        }

        /// Andersson's two-way search (recursive)
        pub fn member2_re(x: T, t: Tree, candidate: ?T) bool {
            if (t) |node| {
                if (x >= node.value) {
                    return member2_re(x, node.right, node.value);
                } else {
                    return member2_re(x, node.left, candidate);
                }
            } else {
                if (candidate) |c| {
                    return c == x;
                }
                return false;
            }
        }

        pub fn member3(x: T, t: Tree) bool {
            var node = t;
            while (node) |curr| {
                const compare = std.math.order(x, curr.value); 
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
