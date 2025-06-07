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
    
    # Calculate throughput metrics for each run
    for run in runs:
        # Conversion factor: (bytes * 1000) / (1024^2)
        c = (run['data_bytes'] * 1000) / (1024.0 * 1024.0)
        
        # Convert time percentiles to throughput
        run['tp_min'] = c / run['max_ms']   # Min throughput
        run['tp_p25'] = c / run['p75_ms']   # 25th percentile throughput
        run['tp_p50'] = c / run['p50_ms']   # 50th percentile throughput
        run['tp_p75'] = c / run['p25_ms']   # 75th percentile throughput
        run['tp_max'] = c / run['min_ms']   # Max throughput
        run['tp_p95'] = c / run['p95_ms']   # 95th percentile throughput (using p95_ms)

    # Sort runs by median throughput (highest first)
    runs.sort(key=lambda x: x['tp_p50'], reverse=True)
    
    # Prepare data and colors
    names = [run['name'] for run in runs]
    tp_p50 = [run['tp_p50'] for run in runs]
    tp_p25 = [run['tp_p25'] for run in runs]
    tp_p75 = [run['tp_p75'] for run in runs]
    tp_p95 = [run['tp_p95'] for run in runs]
    colors = [HIGHLIGHT_COLOR if name.lower() == "utf8-zig" else DEFAULT_COLOR for name in names]
    
    # Calculate error bars: [left = p50-p25, right = p75-p50]
    lower_errors = [tp_p50[i] - tp_p25[i] for i in range(len(tp_p50))]
    upper_errors = [tp_p75[i] - tp_p50[i] for i in range(len(tp_p50))]
    
    # Create figure
    fig, ax = plt.subplots(figsize=(10, 0.8 * len(runs) + 2), dpi=100)
    index = np.arange(len(names))
    bar_height = 0.7
    
    # Plot horizontal bars (highest throughput at top)
    bars = ax.barh(
        index, tp_p50, bar_height,
        xerr=[lower_errors, upper_errors],
        color=colors, ecolor=ERROR_COLOR, capsize=3, alpha=1
    )
    
    # Add value labels (right-aligned)
    max_tp = max(tp_p75)  # Used for text positioning
    for i, (median, p95) in enumerate(zip(tp_p50, tp_p95)):
        # Position text at 105% of the IQR bar end (p75)
        text_x = tp_p75[i] * 1.05
        
        # Use different text color for highlighted bar
        text_color = 'black' if colors[i] == HIGHLIGHT_COLOR else '#333333'
        
        ax.text(
            text_x, i, 
            f"{median:.1f} MB/s\np95: {p95:.1f} MB/s",
            va='center', ha='left', fontsize=10,
            linespacing=1.3, color=text_color, alpha=1
        )
    
    # Configure axes
    ax.set_yticks(index)
    ax.set_yticklabels([textwrap.fill(name, 24) for name in names], fontsize=10)
    ax.set_xlabel('Throughput (MB/s)', fontsize=11)
    ax.set_title(f'Performance: {case_name}', fontsize=13, pad=15, fontweight='bold')
    ax.invert_yaxis()  # Highest throughput at top
    
    # Set x-axis limits with headroom
    ax.set_xlim(0, max_tp * 1.3)
    
    # Use logarithmic scale if values span orders of magnitude
    min_tp = min(tp_p25)
    if max_tp / min_tp > 100:
        ax.set_xscale('log')
        ax.xaxis.set_major_formatter(ticker.FormatStrFormatter('%.1f'))
        ax.set_xlabel('Throughput (MB/s) - Log Scale', fontsize=11)
    
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
