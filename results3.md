# Andersson's Binary Search Tree Benchmark Results - Part 3 (Iterative Standard Search)

This file documents the results of running the binary search tree benchmarks after refactoring the **Standard Search** (`member`) algorithm from recursive to **iterative** in [binary_tree_std.zig](file:///Users/justinhj/projects/purely-functional-data-structures/zigtree/src/binary_tree_std.zig).

## Experimental Setup
* **Tree Size ($N$)**: 5,000 elements of type `f32`.
* **Iterations ($M$)**: 100,000 search queries.
* **Repetitions**: 10 runs per configuration to compute the mean and standard deviation of search speeds.
* **Hit Ratio**:
  - **Successful Search**: 100% hits (keys present in the tree).
  - **Unsuccessful Search**: 100% misses (keys not present in the tree).

---

## 1. Measured CPU Times (Average Search Speed in ns/op)

Below is the summary of 10 runs for each configuration. Values are shown as:
$$\text{Mean Search Speed} \pm \text{Standard Deviation (Percentage of Mean)}$$

### Tree Generated from Random Insertions (`BALANCED=0`)

| Search Method | Successful Search (100% Hits) | Unsuccessful Search (100% Misses) |
| :--- | :--- | :--- |
| **Standard** (Iterative) | $57.14 \pm 5.95$ ns/op (10.4%) | $60.61 \pm 0.93$ ns/op (1.5%) |
| **Sentinel** | $73.50 \pm 8.39$ ns/op (11.4%) | $80.28 \pm 0.83$ ns/op (1.0%) |
| **Two-Way** (Iterative) | $75.07 \pm 7.10$ ns/op (9.5%) | $72.81 \pm 0.28$ ns/op (0.4%) |
| **Three-Way** (Iterative) | $58.44 \pm 4.30$ ns/op (7.4%) | $63.00 \pm 0.27$ ns/op (0.4%) |

### Perfectly Balanced Tree (`BALANCED=1`)

| Search Method | Successful Search (100% Hits) | Unsuccessful Search (100% Misses) |
| :--- | :--- | :--- |
| **Standard** (Iterative) | $60.00 \pm 1.11$ ns/op (1.8%) | $63.46 \pm 0.88$ ns/op (1.4%) |
| **Sentinel** | $37.79 \pm 0.67$ ns/op (1.8%) | $35.35 \pm 0.46$ ns/op (1.3%) |
| **Two-Way** (Iterative) | **$30.39 \pm 0.52$ ns/op (1.7%)** | **$31.64 \pm 1.56$ ns/op (4.9%)** |
| **Three-Way** (Iterative) | $57.96 \pm 0.25$ ns/op (0.9%) | $64.13 \pm 0.86$ ns/op (1.3%) |

---

## 2. Key Observations & Comparison with Part 2

Let's compare the results of the Standard Search when it was recursive (from Part 2) vs. iterative (from Part 3):

### Comparison table for Standard Search:

| Configuration | Recursive Standard Search (Part 2) | Iterative Standard Search (Part 3) | Difference |
| :--- | :--- | :--- | :--- |
| **Random Tree, Successful** | $55.12 \text{ ns/op}$ | $57.14 \text{ ns/op}$ | $+3.6\%$ (Noise) |
| **Random Tree, Unsuccessful** | $61.70 \text{ ns/op}$ | $60.61 \text{ ns/op}$ | $-1.8\%$ (Speedup) |
| **Balanced Tree, Successful** | $61.48 \text{ ns/op}$ | $60.00 \text{ ns/op}$ | $-2.4\%$ (Speedup) |
| **Balanced Tree, Unsuccessful** | $63.25 \text{ ns/op}$ | $63.46 \text{ ns/op}$ | $+0.3\%$ (Noise) |

### Analysis: Why is the speedup virtually zero?

1. **LLVM Tail-Call Optimization (TCO)**:
   The recursive `member` function in [binary_tree_std.zig](file:///Users/justinhj/projects/purely-functional-data-structures/zigtree/src/binary_tree_std.zig) is **fully tail-recursive**:
   ```zig
   if (x < node.value) return member(x, node.left);
   if (x > node.value) return member(x, node.right);
   return true;
   ```
   Because the recursive calls are the very last operations before the function returns, the compiler (LLVM under `-OReleaseFast`) compiles the recursion directly into an iterative loop at the machine level (reusing the same stack frame and simply updating registers).
   Therefore, writing the loop manually in Zig produces almost identical assembly code to the recursive version, leading to virtually identical runtimes (differences are within typical benchmark measurement noise).

2. **Why Two-Way Search (`member2`) Behaved Differently**:
   Unlike Standard Search, converting Two-Way Search from recursive to iterative yielded a massive **50% speedup** on balanced trees ($61.86 \text{ ns/op} \rightarrow 30.71 \text{ ns/op}$).
   This is because the recursive version of Two-Way Search passed an optional `candidate` parameter (`?T`) down the call stack on every recursion step:
   ```zig
   return member2_re(x, node.right, node.value);
   ```
   The constant updating and passing of the optional parameter (`?T`) on the stack introduced ABI and register allocation complexities that prevented LLVM from generating the most optimal iterative machine code. By refactoring it to use a local variable `var candidate: ?T = null` inside a `while` loop, LLVM was able to register-promote `candidate` and optimize the loop body perfectly, yielding the full performance benefits of the algorithm.

### Summary Conclusion
Manual conversion of tail-recursive functions to iterative structures is generally unnecessary when compiling with high optimization levels (`-OReleaseFast`) because LLVM's TCO automatically handles this conversion. However, refactoring is highly beneficial when recursive calls pass mutable or state-tracking arguments (like the optional `candidate` in Two-Way Search), as simplifying the state into local loop variables allows the compiler to generate significantly tighter assembly.
