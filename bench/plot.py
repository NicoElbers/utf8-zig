import sys
import json
import matplotlib.pyplot as plt
import numpy as np

# Load JSON input from stdin
data = json.load(sys.stdin)

def mbps(data_bytes, ms):
    return (data_bytes / 1_000_000) / (ms / 1000)

test_case_names = [tc["name"] for tc in data]
impl_names = sorted({run["name"] for tc in data for run in tc["run"]})

mbps_matrix = []
for tc in data:
    impl_to_run = {r["name"]: r for r in tc["run"]}
    row = []
    for impl in impl_names:
        run = impl_to_run.get(impl)
        if run:
            row.append(mbps(run["data_bytes"], run["p50_ms"]))
        else:
            row.append(0)
    mbps_matrix.append(row)

mbps_matrix = np.array(mbps_matrix).T

x = np.arange(len(test_case_names))
width = 0.8 / len(impl_names)

fig, ax = plt.subplots(figsize=(10, 5))
colors = plt.get_cmap("tab10").colors

for i, impl in enumerate(impl_names):
    offset = (i - len(impl_names)/2) * width + width/2
    bars = ax.bar(
        x + offset,
        mbps_matrix[i],
        width,
        label=impl,
        color=colors[i % len(colors)],
    )
    for bar in bars:
        h = bar.get_height()
        ax.text(
            bar.get_x() + bar.get_width() / 2,
            h + 1,
            f"{h:.0f}",
            ha='center',
            va='bottom',
            fontsize=8,
        )

ax.set_ylabel("Throughput (MB/s)")
ax.set_xlabel("Test Case")
ax.set_title("Throughput by Test Case and Implementation")
ax.set_xticks(x)
ax.set_xticklabels(test_case_names, rotation=15, ha='right')
ax.legend()
ax.grid(True, axis='y', linestyle='--', alpha=0.4)

plt.tight_layout()
plt.savefig("benchmark.png", dpi=150)
