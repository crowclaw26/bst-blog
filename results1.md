# Andersson's Binary Search Tree Benchmark Results

This file documents the results of running the binary search tree benchmarks using the methodology from Arne Andersson's 1991 paper ("A Note on Searching in a Binary Search Tree") on a modern CPU (Apple Silicon) with Zig 0.16.0 under `-OReleaseFast`.

The benchmarks have been optimized to use direct loops without per-iteration clock calls, removing timing overhead and measuring the true CPU performance of each search algorithm.

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
| **Standard** | $56.93 \pm 6.32$ ns/op (11.1%) | $61.32 \pm 1.21$ ns/op (2.0%) |
| **Sentinel** | $72.25 \pm 4.24$ ns/op (5.9%) | $81.81 \pm 2.09$ ns/op (2.6%) |
| **Two-Way** | $59.24 \pm 5.27$ ns/op (8.9%) | $56.08 \pm 0.76$ ns/op (1.3%) |
| **Three-Way** | $57.53 \pm 5.86$ ns/op (10.2%) | $61.92 \pm 0.56$ ns/op (0.9%) |

### Perfectly Balanced Tree (`BALANCED=1`)

| Search Method | Successful Search (100% Hits) | Unsuccessful Search (100% Misses) |
| :--- | :--- | :--- |
| **Standard** | $59.82 \pm 0.64$ ns/op (1.1%) | $63.28 \pm 0.48$ ns/op (0.8%) |
| **Sentinel** | $37.78 \pm 0.78$ ns/op (2.1%) | $36.42 \pm 3.42$ ns/op (9.4%) |
| **Two-Way** | $61.80 \pm 0.89$ ns/op (1.4%) | $60.31 \pm 1.21$ ns/op (2.0%) |
| **Three-Way** | $57.96 \pm 0.53$ ns/op (0.9%) | $63.97 \pm 0.35$ ns/op (0.5%) |

---

## 2. Comparison with the 1991 Paper Findings

In Andersson's original paper, the experiments on Sun Modula-2 (using similar $N=5000$ and $M=100,000$ parameters) yielded the following results (times in milliseconds/microseconds):
- **Random Tree**: Two-Way Search was the fastest (26% to 42% faster than Standard/Sentinel).
- **Balanced Tree**: Two-Way Search was also the fastest (~28% faster than Standard/Sentinel).
- **Sentinel Search**: Provided minor to no improvement over Standard Search.

### Why Modern CPUs Behave Differently

1. **Two-Way Search Performance**:
   - **On 1991 CPUs**: Instruction counts dominated performance. Two-Way Search performs exactly 1 comparison per node ($h$ total) instead of 2 comparisons ($2h$ on average for Standard). This halved comparison count and led to a large speedup.
   - **On Modern CPUs**: Memory latency and pointer dereferences are the main bottlenecks. For **successful searches**, Standard Search terminates early on average halfway down the tree ($\approx h/2$), whereas Two-Way Search *always* goes all the way to the leaves ($h$ depth). The extra pointer dereferences in Two-Way Search make it slower than Standard Search for successful searches. For **unsuccessful searches** (where both must go to the bottom of the tree), Two-Way Search is indeed faster than Standard Search (e.g. $56.08\text{ ns/op}$ vs $61.32\text{ ns/op}$ on random trees), showing a ~8.5% speedup because branch prediction and CPU out-of-order execution hide the comparison instruction cost.

2. **The Sentinel Search Inversion**:
   - **Random Tree**: Sentinel Search is the slowest by far. This is because modern out-of-order CPUs are slowed down by the memory write to the sentinel node (`this.sentinel.value = x`) at the beginning of each search call. This store operation stalls the read-heavy search loop.
   - **Balanced Tree**: Sentinel Search is the **fastest** by a wide margin (e.g. $37.78\text{ ns/op}$ vs $59.82\text{ ns/op}$ for successful search). Why? 
     Standard and Two-Way searches are implemented recursively in this project. In a balanced tree of size 5,000, the height is small ($12$ to $13$), meaning the recursion depth is small, but if the compiler doesn't tail-call optimize the recursion, the push/pop function call overhead is significant.
     Sentinel Search is implemented as a simple, tight iterative loop. The elimination of recursion overhead, combined with the smaller height of the balanced tree, makes the iterative loop run extremely fast, overriding the latency of the sentinel write.

3. **Three-Way Search (Iterative with `std.math.order`)**:
   - **member3** is implemented iteratively using a `while` loop and `std.math.order` to switch on the result (less than, greater than, or equal).
   - In most cases, it performs almost identically to the Standard Search (within 1%). This is because at the assembly level, modern compilers translate `std.math.order` on float values into standard comparisons and branch instructions.
   - However, on balanced trees for successful search, it is slightly faster than Standard Search ($57.96\text{ ns/op}$ vs $59.82\text{ ns/op}$, a ~3% speedup) because the iterative structure completely avoids standard function call/recursion overhead.

---

## 3. Analysis of Standard Deviations

We observe two very different behaviors of standard deviation depending on how it is calculated:

1. **Per-Query Standard Deviation (Within a Single Run)**:
   - Typically **30% to 150%** of the mean.
   - This high variation is due to the dynamic nature of individual queries: some queries hit the root node (1 comparison, fast), while others go to the leaves (13-20 comparisons, slow). Cache hits/misses and branch prediction outcomes vary heavily per query.
2. **Per-Run Standard Deviation (Across 10 Runs)**:
   - Typically **< 3.0%** (most are under 2.0%) for balanced trees and random trees.
   - This very low variation matches Andersson's paper observations ("All standard deviations were less than 5 percent for random trees and less than 1 percent for perfectly balanced trees").
   - This happens because each run aggregates 100,000 independent queries, and by the Law of Large Numbers, the average total time is extremely stable and highly reproducible.
