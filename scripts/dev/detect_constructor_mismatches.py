#!/usr/bin/env python3
"""
detect_constructor_mismatches.py

Static checker for GDScript .new() call-site vs _init signature mismatches.

For every ClassName.new(...) call found in scripts/, this script:
  1. Resolves the class name to its source file
  2. Extracts the _init parameter count
  3. Compares against the actual call-site argument count

Run: python3 scripts/dev/detect_constructor_mismatches.py
Exit: 0 = clean, 1 = mismatch(s) found
"""

import sys
import re
import os
from pathlib import Path
from collections import defaultdict

SCRIPTS_DIR = Path(__file__).parent.parent.parent / "scripts"


def get_init_params(content: str) -> tuple[int, int] | None:
    """
    Extract _init parameter count and minimum required (no defaults) from a class file.
    Returns (total_params, required_params) or None if no _init found.
    """
    # Find class definition
    class_match = re.search(r"class_name\s+(\w+)", content)
    if not class_match:
        # No class_name — anonymous class, skip
        return None

    # Find _init function
    # Match: func _init(p1, p2=default, ...):
    init_pat = re.compile(
        r"func\s+_init\s*\(([^)]*)\)\s*:",
        re.MULTILINE | re.DOTALL,
    )
    match = init_pat.search(content)
    if not match:
        # No _init at all — treat as 0 params, 0 required
        return (0, 0)

    params_str = match.group(1).strip()
    if not params_str:
        return (0, 0)

    total = 0
    required = 0
    for p in params_str.split(","):
        p = p.strip()
        if not p:
            continue
        total += 1
        # Required if no default value (no = in the param spec)
        # Handle "p: Type = val" and "p = val" patterns
        param_body = p.split("=")[0].strip()
        # If there's a type hint, strip it before checking for default
        if ":" in param_body:
            type_and_name = param_body.split(":")
            param_body = type_and_name[0].strip()
        if "=" not in p and param_body != "":
            required += 1

    return (total, required)


def find_class_file(class_name: str, scripts_dir: Path) -> Path | None:
    """Find the .gd file that defines the given class_name."""
    for gd in scripts_dir.rglob("*.gd"):
        try:
            content = gd.read_text(encoding="utf-8")
        except Exception:
            continue
        if re.search(r"class_name\s+" + re.escape(class_name), content):
            return gd
    return None


def check_new_calls(scripts_dir: Path):
    """
    Find all .new() calls in scripts/, resolve classes, compare arities.
    Returns list of (file, line, class_name, call_args, init_params, issue).
    """
    issues = []

    # Map: class_name -> (init_total, init_required)
    init_cache: dict[str, tuple[int, int] | None] = {}

    # Find all .new() call sites
    new_call_pat = re.compile(
        r"\.new\s*\(\s*([^)]*)\s*\)",  # captures everything inside .new()
    )

    for gd in scripts_dir.rglob("*.gd"):
        # Skip dev/ scripts (test utilities, not shipped)
        if "/dev/" in str(gd) or "\\dev\\" in str(gd):
            continue
        try:
            lines = gd.read_text(encoding="utf-8").split("\n")
        except Exception:
            continue

        for lineno, line in enumerate(lines, 1):
            # Simple comment guard
            stripped = line.strip()
            if stripped.startswith("#"):
                continue

            for m in new_call_pat.finditer(line):
                args_str = m.group(1).strip()

                # Count arguments (split by comma, count non-empty)
                if args_str:
                    # Count args, handling nested calls carefully
                    # Use a simple depth counter instead of naive split
                    depth = 0
                    arg_count = 0
                    for ch in args_str:
                        if ch == "," and depth == 0:
                            arg_count += 1
                        elif ch in "([{":
                            depth += 1
                        elif ch in ")]}":
                            depth -= 1
                    call_arg_count = arg_count + 1
                else:
                    call_arg_count = 0

                # Try to find the class name before .new()
                # Look backwards from .new( for the identifier
                prefix = line[: m.start()]
                # Find the last word before .new
                idents = re.findall(r"\b([A-Z][A-Za-z0-9_]*)\b", prefix)
                if not idents:
                    continue
                class_name = idents[-1]

                # Cache the _init signature
                if class_name not in init_cache:
                    class_file = find_class_file(class_name, scripts_dir)
                    if class_file:
                        content = class_file.read_text(encoding="utf-8")
                        init_cache[class_name] = get_init_params(content)
                    else:
                        init_cache[class_name] = None

                init_info = init_cache[class_name]
                if init_info is None:
                    # Can't resolve — class not found in scripts/, might be a Godot built-in
                    continue

                init_total, init_required = init_info

                # Check mismatch
                if call_arg_count < init_required:
                    issue = f"too few args: got {call_arg_count}, need at least {init_required} (class {class_name})"
                    issues.append((str(gd.relative_to(scripts_dir.parent)), lineno, class_name, call_arg_count, init_info, issue))
                elif call_arg_count > init_total:
                    issue = f"too many args: got {call_arg_count}, max {init_total} (class {class_name})"
                    issues.append((str(gd.relative_to(scripts_dir.parent)), lineno, class_name, call_arg_count, init_info, issue))


def main():
    print("=== Constructor Call-Site vs _init Signature Check ===\n")

    scripts_dir = SCRIPTS_DIR
    if not scripts_dir.exists():
        print(f"ERROR: {scripts_dir} not found", file=sys.stderr)
        sys.exit(1)

    issues = check_new_calls(scripts_dir)

    if not issues:
        gd_files = list(scripts_dir.rglob("*.gd"))
        dev_skip = [f for f in gd_files if "/dev/" in str(f) or "\\dev\\" in str(f)]
        print(f"PASSED: No constructor mismatches ({len(gd_files) - len(dev_skip)} scripts checked)")
        sys.exit(0)

    print(f"FAILED: {len(issues)} constructor mismatch(s) found:\n")
    for file, lineno, class_name, call_args, (init_total, init_required), issue in issues:
        print(f"  {file}:{lineno} — {issue}")
        print(f"    {class_name}._init() signature: {init_required} required, {init_total} total params")
        print(f"    Call site: .{class_name}.new({call_args} args)")
        print()
    print(f"TOTAL: {len(issues)} mismatch(s)")
    sys.exit(1)


if __name__ == "__main__":
    main()
