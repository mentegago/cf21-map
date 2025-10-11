#!/usr/bin/env python3
"""
Convert map.csv to map.json for reliable loading in Flutter web.
"""
import csv
import json
import sys
from pathlib import Path

def convert_csv_to_json(csv_path, json_path):
    """Convert CSV file to JSON array of arrays."""
    grid = []
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        for row in reader:
            grid.append(row)
    
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(grid, f, ensure_ascii=False, indent=2)
    
    print(f"[OK] Converted {csv_path} to {json_path}")
    print(f"  Rows: {len(grid)}")
    print(f"  Cols: {len(grid[0]) if grid else 0}")

if __name__ == '__main__':
    # Get project root (assume script is in tools/)
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    csv_file = project_root / 'data' / 'map.csv'
    json_file = project_root / 'data' / 'map.json'
    
    if not csv_file.exists():
        print(f"Error: {csv_file} not found")
        sys.exit(1)
    
    convert_csv_to_json(csv_file, json_file)

