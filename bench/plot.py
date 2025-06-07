# Written by deepseek, I can't be fucked to write python tbh

import json
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np
import textwrap

# Load benchmark data
with open('data.json') as f:
    test_cases = json.load(f)

# Configure colors
DEFAULT_COLOR = '#AAAAAA'  # Light grey
HIGHLIGHT_COLOR = '#FFD700'  # Bright yellow (gold)
ERROR_COLOR = '#666666'  # Dark grey for error bars

for case in test_cases:
    case_name = case['name']
    runs = case['run']
    
    # Sort runs by median performance (fastest first)
    runs.sort(key=lambda x: x['p50_ms'])
    
    # Prepare data and colors
    names = [run['name'] for run in runs]
    p50 = [run['p50_ms'] for run in runs]
    p75 = [run['p75_ms'] for run in runs]
    p25 = [run['p25_ms'] for run in runs]
    colors = [HIGHLIGHT_COLOR if name.lower() == "utf8-zig" else DEFAULT_COLOR for name in names]
    
    # Create figure with optimal size
    fig, ax = plt.subplots(figsize=(10, 0.8 * len(runs) + 2), dpi=100)
    index = np.arange(len(names))
    bar_height = 0.7
    
    # Plot horizontal bars (fastest at top)
    bars = ax.barh(
        index, p50, bar_height,
        xerr=[np.subtract(p50, p25), np.subtract(p75, p50)],
        color=colors, ecolor=ERROR_COLOR, capsize=3, alpha=1
    )
    
    # Add value labels (right-aligned)
    max_time = max(p75)  # Used for text positioning
    for i, (median, p95) in enumerate(zip(p50, [run['p95_ms'] for run in runs])):
        # Position text at 105% of the IQR bar end (p75)
        text_x = max(p75[i], p50[i]) * 1.05
        
        # Use different text color for highlighted bar
        text_color = 'black' if colors[i] == HIGHLIGHT_COLOR else '#333333'
        
        ax.text(
            text_x, i, 
            f"{median:.1f} ms\np95: {p95:.1f} ms",
            va='center', ha='left', fontsize=10,
            linespacing=1.3, color=text_color, alpha=1
        )
    
    # Configure axes
    ax.set_yticks(index)
    ax.set_yticklabels([textwrap.fill(name, 24) for name in names], fontsize=10)
    ax.set_xlabel('Time (ms)', fontsize=11)
    ax.set_title(f'Performance: {case_name}', fontsize=13, pad=15, fontweight='bold')
    ax.invert_yaxis()  # Fastest at top
    
    # Set x-axis limits with headroom
    ax.set_xlim(0, max_time * 1.3)
    
    # Use logarithmic scale if values span orders of magnitude
    max_time = max(run['p95_ms'] for run in runs)
    min_time = min(run['p25_ms'] for run in runs)
    if max_time / min_time > 100:
        ax.set_xscale('log')
        ax.xaxis.set_major_formatter(ticker.FormatStrFormatter('%.1f'))
        ax.set_xlabel('Time (ms) - Log Scale', fontsize=11)
    
    # Add subtle grid and clean borders
    ax.xaxis.grid(True, linestyle='--', alpha=0.4)
    ax.spines[['right', 'top']].set_visible(False)
    ax.spines[['left', 'bottom']].set_color('#dddddd')
    
    plt.tight_layout()
    
    # Save as high-quality PNG
    filename = f"perf_{case_name.lower().replace(' ', '_')}.png"
    plt.savefig(filename, bbox_inches='tight', dpi=120, transparent=False)
    plt.close()
    
    print(f'Generated: {filename}')
