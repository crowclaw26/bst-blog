const std = @import("std");

/// A Binary Search Tree (BST) that optimizes search and insertion loops by using a shared sentinel leaf.
///
/// This implementation uses a sentinel search technique where the search key is copied into the 
/// sentinel node itself before traversal (`sentinel.value = x`). This guarantees that the search loop 
/// will always terminate, eliminating the need to check for null pointers or sentinel equality 
/// inside the inner loop (reducing the loop condition from two checks to one comparison).
///
/// Reference:
///   Niklaus Wirth, "Algorithms + Data Structures = Programs" (1976),
///   Chapter 4: Dynamic Information Structures, Section 4.4: Binary Trees.
pub fn BinaryTreeSentinel(comptime T: type) type {
    return struct {
        const This = @This();
        pub const Node = struct {
            value: T,
            left: ?*Node = null,
            right: ?*Node = null,
        };

        root: ?*Node = null,
        sentinel: *Node,

        pub const Tree = ?*Node;

        pub fn init(gpa: std.mem.Allocator) !This {
            const sentinel_node = try gpa.create(Node);
            sentinel_node.* = .{ .value = undefined, .left = null, .right = null };
            return This {
                .root = null,
                .sentinel = sentinel_node,
            };
        }

        pub fn setSentinel(this: *This, value: T) void {
            this.sentinel.value = value;
        }

        fn createNode(this: *This, allocator: std.mem.Allocator, value: T) !*Node {
            const new_node = try allocator.create(Node);
            new_node.* =  .{ .value = value, .left = this.sentinel, .right = this.sentinel };
            return new_node;
        }

        pub fn insert(this: *This, allocator: std.mem.Allocator, value: T) !void {
            var curr = this.root orelse {
                const new_node = try this.createNode(allocator, value);
                this.root = new_node;
                return;
            };

            var parent: *Node = undefined;
            this.sentinel.value = value; // set the sentinel for the current search
            
            while (value != curr.value) {
                parent = curr;
                if (value < curr.value) {
                    curr = curr.left.?;
                } else {
                    curr = curr.right.?;
                }
            }

            if (curr != this.sentinel) {
                // Value already exists in the tree
                return;
            }

            // Value not found (we reached sentinel). Create a new node.
            const new_node = try allocator.create(Node);
            new_node.* = .{ .value = value, .left = this.sentinel, .right = this.sentinel };

            if (value < parent.value) {
                parent.left = new_node;
            } else {
                parent.right = new_node;
            }
        }

        pub fn member(this: *This, x: T) bool {
            var curr = this.root orelse return false;
            this.sentinel.value = x;
            while (x != curr.value) {
                if (x < curr.value) {
                    curr = curr.left.?;
                } else {
                    curr = curr.right.?;
                }
            }
            return curr != this.sentinel;
        }
    };
}

test "BinaryTreeSentinel basic test" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const FloatTree = BinaryTreeSentinel(f32);
    var tree = try FloatTree.init(allocator);
    tree.setSentinel(10.0);
    try std.testing.expect(tree.sentinel.value == 10.0);

    try tree.insert(allocator, 5.0);
    try tree.insert(allocator, 3.0);
    try tree.insert(allocator, 7.0);
    try tree.insert(allocator, 8.0);

    try std.testing.expect(tree.member(5.0) == true);
    try std.testing.expect(tree.member(3.0) == true);
    try std.testing.expect(tree.member(8.0) == true);
    try std.testing.expect(tree.member(4.0) == false);
    try std.testing.expect(tree.member(7.0) == true);
    try std.testing.expect(tree.member(9.0) == false);
}

test "BinaryTreeSentinel empty tree test" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const FloatTree = BinaryTreeSentinel(f32);
    var tree = try FloatTree.init(allocator);
    try std.testing.expect(tree.member(9.0) == false);
}
