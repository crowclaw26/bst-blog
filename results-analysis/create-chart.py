import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

# Load and prep data
df = pd.read_csv('results.csv')
cpu_mapping = {
    'Intel(R) Core(TM) i5-7500T CPU @ 2.70GHz': 'Intel i5-7500T',
    'Apple M1 Pro': 'Apple M1 Pro',
    'AMD Ryzen 7 7700X 8-Core Processor 8 16 4501': 'AMD Ryzen 7 7700X',
    'Apple M4 Pro': 'Apple M4 Pro'
}
df['CPU_Short'] = df['CPU'].map(cpu_mapping).fillna(df['CPU'])

sns.set_theme(style="whitegrid")

# Option 1: Faceted Grid (Small Multiples)
# This creates a 2x2 grid of charts that share the same Y-axis scale
g = sns.catplot(
    data=df, kind="bar",
    x="CPU_Short", y="Mean (ns/op)", hue="Test",
    col="Search Type", row="Tree Type",
    palette="Set2", height=4, aspect=1.5,
    sharey=True # crucial for comparison!
)

g.set_axis_labels("CPU", "Mean Time (ns/op)")
g.set_titles(row_template="{row_name} Tree", col_template="{col_name} Search", size=14)

# Rotate x-axis labels for readability
for ax in g.axes.flat:
    for label in ax.get_xticklabels():
        label.set_rotation(15)

# Move legend out of the way
sns.move_legend(g, "upper right", bbox_to_anchor=(1.05, 0.6))
plt.tight_layout()
g.savefig("combined_facet_grid.png", dpi=150, bbox_inches='tight')
plt.close()


# Option 2: Heatmap
# Pivot the data to create a matrix of values
pivot_df = df.pivot_table(
    index=['CPU_Short', 'Test'], 
    columns=['Tree Type', 'Search Type'], 
    values='Mean (ns/op)'
)

# Flatten columns and index for cleaner, non-overlapping labels
pivot_df.columns = [f"{tree.capitalize()} Tree\n({search} Search)" for tree, search in pivot_df.columns]
pivot_df.index = [f"{cpu} ({test})" for cpu, test in pivot_df.index]

plt.figure(figsize=(11, 9))
sns.heatmap(pivot_df, annot=True, fmt=".1f", cmap="YlOrRd", cbar_kws={'label': 'Mean Time (ns/op)'})
plt.title('Benchmark Heatmap: Mean Search Times', fontsize=16, pad=15)
plt.ylabel('CPU & Test Method', fontsize=12)
plt.xlabel('Tree Type & Search Type', fontsize=12)
plt.xticks(rotation=0)  # Keep x-axis labels horizontal and clean
plt.tight_layout()
plt.savefig("benchmark_heatmap.png", dpi=150, bbox_inches='tight')
plt.close()

print("Saved combined_facet_grid.png and benchmark_heatmap.png")
