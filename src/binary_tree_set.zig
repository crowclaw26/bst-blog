const std = @import("std");

/// A purely functional binary tree set.
pub fn BinaryTreeSet(comptime T: type) type {
    return struct {
        pub const Node = struct {
            value: T,
            // We use optional constant pointers for immutability and the 'Empty' state
            left: ?*const Node = null,
            right: ?*const Node = null,
        };

        // Alias for the root type
        pub const Tree = ?*const Node;

        /// Inserts a value into the tree. Since it's purely functional, it returns
        /// a new tree, allocating new nodes where the path diverges.
        pub fn insert(allocator: std.mem.Allocator, x: T, t: Tree) !Tree {
            // If the tree is not empty, unwrap the pointer to 'node'
            if (t) |node| {
                if (x < node.value) {
                    const new_node = try allocator.create(Node);
                    new_node.* = .{
                        .value = node.value,
                        .left = try insert(allocator, x, node.left),
                        .right = node.right,
                    };
                    return new_node;
                } else if (x > node.value) {
                    const new_node = try allocator.create(Node);
                    new_node.* = .{
                        .value = node.value,
                        .left = node.left,
                        .right = try insert(allocator, x, node.right),
                    };
                    return new_node;
                } else {
                    return t; // Value already exists, return existing tree
                }
            } else {
                // Tree.Empty case
                const new_node = try allocator.create(Node);
                new_node.* = .{ .value = x };
                return new_node;
            }
        }

        /// Basic version of member (2 comparisons per node)
        pub fn member(x: T, t: Tree) bool {
            if (t) |node| {
                if (x < node.value) return member(x, node.left);
                if (x > node.value) return member(x, node.right);
                return true;
            }
            return false;
        }

        /// Optimized version of member taking d+1 max comparisons
        pub fn member2(x: T, t: Tree, candidate: ?T) bool {
            if (t) |node| {
                if (x >= node.value) {
                    return member2(x, node.right, node.value);
                } else {
                    return member2(x, node.left, candidate);
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
