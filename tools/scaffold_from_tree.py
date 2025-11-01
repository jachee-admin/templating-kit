#!/usr/bin/env python3
"""
scaffold_from_tree.py — Create folders/files from an ASCII tree in Markdown.

Parses trees like:

prompt-coach/
├── README.md
├── pyproject.toml
├── coach
│   ├── __init__.py
│   ├── heuristics.py
│   ├── scorer.py
│   ├── openai_client.py
│   ├── templates.py
│   └── utils.py
├── cli.py
├── server.py
├── tests
│   ├── test_heuristics.py
│   └── test_scorer.py
└── .env.example

Usage:
  python tools/scaffold_from_tree.py --root . --from-file tree.md
  cat tree.md | python tools/scaffold_from_tree.py --root . --stdin
  python tools/scaffold_from_tree.py --root . --text "prompt-coach/ ... (one-liner)"
Options:
  --dry-run      show what would be created, make nothing
  --force        overwrite existing empty files
  --touch-dirs   create intermediate dirs even if parent is a file line
  --default-file-content "..."  put this text in newly created files
"""
from __future__ import annotations
import sys, os, argparse, io, re
from pathlib import Path

TREE_CHARS = "│├└─"

def load_source(args: argparse.Namespace) -> str:
    if args.stdin:
        return sys.stdin.read()
    if args.text:
        return args.text
    if args.from_file:
        return Path(args.from_file).read_text(encoding="utf-8")
    raise SystemExit("Provide --stdin, --text, or --from-file")

def extract_tree_block(markdown: str) -> str:
    """
    Heuristic: prefer the largest fenced code block; fallback to raw text.
    """
    fences = re.findall(r"```(?:[a-zA-Z0-9_-]*)\n(.*?)```", markdown, flags=re.S)
    if fences:
        # pick the longest block that looks like a tree
        fences = sorted(fences, key=len, reverse=True)
        for block in fences:
            if any(ch in block for ch in TREE_CHARS) or (" /" in block) or ("\\" in block):
                return block.strip()
        return fences[0].strip()
    return markdown.strip()

def is_tree_line(line: str) -> bool:
    if not line.strip():
        return False
    # Accepts lines that either start the root or contain tree connectors
    return any(x in line for x in ("├", "└", "│", "──")) or "/" in line or "\\" in line

def parse_tree_lines(block: str) -> list[str]:
    lines = [ln.rstrip() for ln in block.splitlines() if is_tree_line(ln)]
    # Trim leading non-tree chatter (e.g., caption lines)
    return lines

def normalize_root_and_entries(lines: list[str]) -> tuple[Path, list[tuple[str, bool]]]:
    """
    Returns (root_path_from_first_line, entries)
    entries: list of (relative_path_str, is_dir)
    """
    if not lines:
        return Path("."), []

    # First non-empty line is the root line, e.g., "prompt-coach/" or "."
    root_line = lines[0].strip()
    root_name = root_line.strip(TREE_CHARS + " ").strip()
    # Allow plain "prompt-coach/" or "./prompt-coach"
    # Pull only last path segment if there's tree chars
    root_name = root_name.split()[-1]
    # Remove tree connectors if any
    root_name = re.sub(r"[{} ]".format(TREE_CHARS), "", root_name).strip()
    # If line ends with '/', treat as dir; else as dir anyway (tree roots are dirs)
    root_dir = Path(root_name.rstrip("/"))

    entries: list[tuple[str, bool]] = []
    dir_stack = []  # Stack to track current directory path

    # Parse tree structure with proper nesting
    for ln in lines[1:]:
        # Calculate indentation level by counting tree characters and spaces
        original_line = ln
        indent_match = re.match(r'^([\s│]*)', ln)
        indent_level = len(indent_match.group(1)) if indent_match else 0

        # Clean up the line to get just the filename/dirname
        s = re.sub(r"^[\s{}]+".format(TREE_CHARS), "", ln)
        s = re.sub(r"^├──\s*|^└──\s*|^──\s*", "", s)
        s = s.strip()
        if not s:
            continue

        # Remove comments
        s = s.split("#", 1)[0].strip()
        if not s:
            continue

        # Determine if this is a directory or file
        # Check for trailing slash OR if the next line is more indented (has children)
        is_dir = s.endswith("/") or s.endswith(os.sep)
        filename = s.rstrip("/").strip()

        # Check if next lines are more indented to determine if this is a directory
        if not is_dir and len(lines) > lines.index(original_line) + 1:
            next_lines = lines[lines.index(original_line) + 1:]
            for next_ln in next_lines:
                if not next_ln.strip():
                    continue
                next_indent_match = re.match(r'^([\s│]*)', next_ln)
                next_indent = len(next_indent_match.group(1)) if next_indent_match else 0
                if next_indent > indent_level:
                    is_dir = True
                    break
                elif next_indent <= indent_level:
                    break

        # Adjust directory stack based on indentation
        # Count actual tree depth by counting tree connection characters
        tree_depth = len(re.findall(r'[│├└]', original_line[:indent_level + 10]))

        # Adjust stack to current depth
        while len(dir_stack) >= tree_depth:
            dir_stack.pop()

        # Build full relative path
        if dir_stack:
            rel_path = "/".join(dir_stack + [filename])
        else:
            rel_path = filename

        entries.append((rel_path, is_dir))

        # If this is a directory, add it to the stack for subsequent entries
        if is_dir:
            dir_stack.append(filename)

    return root_dir, entries

def create_scaffold(root: Path, entries: list[tuple[str, bool]], *,
                    base_root: Path, dry: bool, force: bool,
                    default_file_content: str | None):
    actions = []
    # Ensure root exists
    root_abs = base_root / root
    actions.append(("mkdir", str(root_abs)))
    if not dry:
        root_abs.mkdir(parents=True, exist_ok=True)

    for rel, is_dir in entries:
        target = root_abs / rel
        if is_dir:
            actions.append(("mkdir", str(target)))
            if not dry:
                target.mkdir(parents=True, exist_ok=True)
        else:
            # Ensure parent dir
            if not dry:
                target.parent.mkdir(parents=True, exist_ok=True)
            actions.append(("touch", str(target)))
            if not dry:
                if target.exists():
                    if force and target.is_file() and target.stat().st_size == 0:
                        pass  # will overwrite empty file
                    elif force and target.is_file():
                        pass  # overwrite anyway
                    else:
                        # keep existing; don't clobber
                        continue
                target.write_text(default_file_content or "", encoding="utf-8")
    return actions

def main():
    ap = argparse.ArgumentParser()
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--stdin", action="store_true", help="Read tree from stdin")
    src.add_argument("--text", help="Provide tree text directly")
    src.add_argument("--from-file", help="Read tree from a Markdown file")

    ap.add_argument("--root", default=".", help="Base directory to create content in (default: .)")
    ap.add_argument("--dry-run", action="store_true", help="List actions, make no changes")
    ap.add_argument("--force", action="store_true", help="Overwrite existing files")
    ap.add_argument("--default-file-content", default="", help="Content to place into new files")

    args = ap.parse_args()
    base_root = Path(args.root).resolve()

    markdown = load_source(args)
    #print(markdown)
    #sys.exit()

    block = extract_tree_block(markdown)
    # print(block)
    # sys.exit()
    lines = parse_tree_lines(block)
    root_dir, entries = normalize_root_and_entries(lines)
    # print(f"root dir: {root_dir}")
    # print(entries)
    # sys.exit()
    if not entries and root_dir == Path("."):
        print("No entries parsed; is your tree block correct?", file=sys.stderr)
        sys.exit(1)

    actions = create_scaffold(root_dir, entries,
                              base_root=base_root,
                              dry=args.dry_run,
                              force=args.force,
                              default_file_content=args.default_file_content)

    for a, p in actions:
        print(f"{a:6}  {p}")

if __name__ == "__main__":
    main()
