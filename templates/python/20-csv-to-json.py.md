---
id: python/csv-to-json
lang: python
since: "v0.1"
tags: [csv, json, cli]
description: "Simple CSV→JSONL converter (streaming)"
---

### Python: CSV to JSON
```python
import csv, json, sys

def run(in_path, out_path="-"):
    fin = open(in_path, newline='', encoding='utf-8') if in_path != "-" else sys.stdin
    fout = open(out_path, "w", encoding='utf-8') if out_path != "-" else sys.stdout
    reader = csv.DictReader(fin)
    for row in reader:
        fout.write(json.dumps(row, ensure_ascii=False) + "\n")
    if fin is not sys.stdin: fin.close()
    if fout is not sys.stdout: fout.close()

if __name__ == "__main__":
    in_path = sys.argv[1] if len(sys.argv) > 1 else "-"
    out_path = sys.argv[2] if len(sys.argv) > 2 else "-"
    run(in_path, out_path)
```
