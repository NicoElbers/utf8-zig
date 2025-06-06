import json
import sys
import os
import re
import matplotlib.pyplot as plt
import numpy as np
from matplotlib import cm
from matplotlib.lines import Line2D
from matplotlib.patches import Rectangle

def sanitize_filename(name):
    """Remove invalid characters from filenames"""
    return re.sub(r'[\\/*?:"<>|]', "_", name)

# Load JSON data from stdin
data = json.load(sys.stdin)

# Prepare color palette
colors = cm.viridis(np.linspace(0, 1, 10))

# Create output directory if it doesn't exist
output_dir = "benchmark_plots"
os.makedirs(output_dir, exist_ok=True)

# Create a separate plot for each test case
for test_case in data:
    test_name = test_case['name']
    runs = test_case['run']
    
    # Create figure for this test case
    fig, ax = plt.subplots(figsize=(12, 6))
    x_pos = np.arange(len(runs))
    bar_width = 0.7
    
    # Plot each run in the test case
    for i, run in enumerate(runs):
        # Calculate quartile positions
        q1 = run['p25_ms']
        median = run['p50_ms']
        q3 = run['p75_ms']
        
        # Draw IQR box (from Q1 to Q3)
        ax.bar(i, q3 - q1, bottom=q1, width=bar_width, 
               color=colors[i % len(colors)], alpha=0.7)
        
        # Draw median line
        ax.hlines(median, i - bar_width/2, i + bar_width/2, 
                 colors='white', linewidth=2, zorder=3)
        
        # Draw min/max whiskers
        ax.vlines(i, run['min_ms'], run['max_ms'], 
                 colors='gray', linewidth=1, alpha=0.7)
        
        # Add min/max caps
        ax.hlines(run['min_ms'], i - bar_width/3, i + bar_width/3, 
                 colors='gray', linewidth=1)
        ax.hlines(run['max_ms'], i - bar_width/3, i + bar_width/3, 
                 colors='gray', linewidth=1)
        
        # Add p95 marker
        ax.scatter(i, run['p95_ms'], marker='x', color='red', s=70, zorder=4)
        
        # Add median value label
        ax.text(i + 0.4, median, f'{median:.2f}ms', 
               va='center', fontsize=9)
    
    # Configure plot
    ax.set_xticks(x_pos)
    ax.set_xticklabels([run['name'] for run in runs])
    ax.set_ylabel('Time (ms)')
    ax.set_title(f'Performance Distribution: {test_name}')
    ax.grid(axis='y', linestyle='--', alpha=0.7)
    
    # Create legend
    median_line = Line2D([], [], color='white', linewidth=2, label='Median (p50)')
    p95_marker = Line2D([], [], color='red', marker='x', linestyle='None', 
                       markersize=8, label='p95')
    minmax_line = Line2D([], [], color='gray', linewidth=1, label='Min/Max Range')
    iqr_box = Rectangle((0,0), 1, 1, fc=colors[0], alpha=0.7, label='IQR (p25-p75)')
    ax.legend(handles=[median_line, p95_marker, minmax_line, iqr_box])
    
    # Save to file instead of showing
    safe_name = sanitize_filename(test_name)
    filename = os.path.join(output_dir, f"{safe_name}.png")
    plt.tight_layout()
    plt.savefig(filename, dpi=150)
    plt.close(fig)  # Close the figure to free memory
    
    print(f"Saved plot for '{test_name}' to {filename}")

print(f"\nAll plots saved to {output_dir}/ directory")
