# Andersson's Binary Search Tree Benchmark Results - Part 2 (Iterative Two-Way Search)

This file documents the results of running the binary search tree benchmarks after refactoring the **Two-Way Search** algorithm from recursive to **iterative** in [binary_tree_std.zig](file:///Users/justinhj/projects/purely-functional-data-structures/zigtree/src/binary_tree_std.zig).

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
| **Standard** | $55.12 \pm 0.55$ ns/op (1.0%) | $61.70 \pm 1.80$ ns/op (2.9%) |
| **Sentinel** | $72.92 \pm 6.25$ ns/op (8.6%) | $81.37 \pm 2.22$ ns/op (2.7%) |
| **Two-Way** (Iterative) | $75.34 \pm 8.21$ ns/op (10.9%) | $74.24 \pm 2.12$ ns/op (2.9%) |
| **Three-Way** (Iterative) | $58.12 \pm 4.33$ ns/op (7.4%) | $64.12 \pm 1.75$ ns/op (2.7%) |

### Perfectly Balanced Tree (`BALANCED=1`)

| Search Method | Successful Search (100% Hits) | Unsuccessful Search (100% Misses) |
| :--- | :--- | :--- |
| **Standard** | $61.48 \pm 5.92$ ns/op (9.6%) | $63.25 \pm 0.73$ ns/op (1.2%) |
| **Sentinel** | $37.90 \pm 0.91$ ns/op (2.4%) | $35.50 \pm 0.45$ ns/op (1.3%) |
| **Two-Way** (Iterative) | **$30.71 \pm 0.54$ ns/op (1.8%)** | **$31.28 \pm 0.17$ ns/op (0.6%)** |
| **Three-Way** (Iterative) | $58.75 \pm 1.14$ ns/op (1.9%) | $63.77 \pm 0.20$ ns/op (0.3%) |

---

## 2. Key Observations & Conclusion

The transition of **Two-Way Search** from recursive to iterative has had a massive impact on performance, validating Andersson's 1991 paper under specific hardware constraints.

### 1. The Triumph of Iterative Two-Way Search on Balanced Trees
On a perfectly balanced tree (`BALANCED=1`), **Two-Way Search (Iterative)** is now the **absolute fastest** method:
* **Successful Search**: At **30.71 ns/op**, it is **50% faster** than Standard Search (61.48 ns/op) and **19% faster** than Sentinel Search (37.90 ns/op).
* **Unsuccessful Search**: At **31.28 ns/op**, it is **50.5% faster** than Standard Search (63.25 ns/op) and **11.9% faster** than Sentinel Search (35.50 ns/op).

#### Why is it so fast?
1. **No Recursion Overhead**: Previously, the recursive version suffered from stack push/pop overhead. The iterative `while` loop completely eliminates this, compiling to a very tight sequence of registers and jumps.
2. **Exactly 1 Comparison Per Node**: While Standard Search does 2 comparisons on average per node (checking `<` and `>`), Two-Way Search only performs 1 comparison (`x < curr.value`), halving comparison work.
3. **No Memory Writes**: Unlike Sentinel Search, which must write to memory (`this.sentinel.value = x`) at the start of every search and trigger store-buffer stalls, Two-Way Search is purely read-only, allowing modern CPU pipelining and out-of-order execution to run at maximum throughput.

### 2. The Bottleneck of Random Trees (Memory Latency vs. Comparison Count)
On a randomly generated tree (`BALANCED=0`), Two-Way Search (75.34 ns/op) is slower than Standard Search (55.12 ns/op).
* **Standard Search** has early-termination capability (it returns as soon as `x == node.value`), visiting on average $\approx h/2$ nodes for successful search.
* **Two-Way Search** *always* traverses all the way to the leaf level ($h$ nodes visited) before verifying the candidate.
* On a random tree of size 5,000, the height is larger and unbalanced (often up to 20-30 nodes deep). Visiting twice the number of nodes causes significantly more L1/L2 cache line lookups and memory latency, which dominates execution time on modern hardware and offsets the benefit of fewer comparisons.

### Summary Conclusion
Arne Andersson's premise that **Two-Way Search** is superior is **strongly verified on modern hardware for balanced BSTs**, where the search depth is bounded and predictable. When combined with an **iterative implementation** that avoids function call overhead, Two-Way Search yields a **50% speedup** over traditional standard binary tree search algorithms.
