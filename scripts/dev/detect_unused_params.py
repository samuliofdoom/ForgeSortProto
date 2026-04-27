#!/usr/bin/env python3
"""
detect_unused_params.py
Static checker for GDScript unused function parameters.

Finds all func definitions, extracts parameter names, and checks whether
each parameter name appears in the function body.  Parameters prefixed with
_ are considered intentionally suppressed and are skipped.

Run directly:  python3 scripts/dev/detect_unused_params.py
Or via validate.sh as part of the CI check.
"""

import sys
import re
import os
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent.parent.parent / "scripts"


def strip_comments(content: str) -> str:
    """Remove # comment lines while preserving line structure."""
    lines = content.split("\n")
    result = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("#"):
            result.append("")
        else:
            result.append(line)
    return "\n".join(result)


def get_func_body(content: str, func_start: int) -> str:
    """Extract the body of a function starting at func_start (byte offset)."""
    # Find the line the function starts on to determine its indent
    line_start = content.rfind("\n", 0, func_start) + 1
    func_line = content[line_start:]
    indent = len(func_line) - len(func_line.lstrip())

    # Everything after the func signature
    rest = content[func_start:]

    body_lines = []
    for line in rest.split("\n"):
        s = line.strip()
        # Stop at another toplevel declaration (func/class at same or lower indent)
        if (
            s.startswith("func ")
            or s.startswith("class ")
            or s.startswith("static func ")
        ):
            break
        body_lines.append(line)

    return "\n".join(body_lines)


def extract_params(params_str: str) -> list[str]:
    """Parse a GDScript parameter list and return parameter names."""
    params = []
    for p in params_str.split(","):
        p = p.strip()
        if not p:
            continue
        # Parameter name is the part before any : (type hint) or = (default)
        name = re.split(r"[:=]", p)[0].strip()
        params.append(name)
    return params


def check_file(filepath: Path) -> list[tuple[str, str, str]]:
    """
    Check a single .gd file for unused parameters.
    Returns list of (func_name, param_name) tuples.
    """
    content = filepath.read_text(encoding="utf-8")
    active = strip_comments(content)

    issues = []
    # Match: func name(params):
    func_pat = re.compile(r"func\s+([_a-zA-Z][_a-zA-Z0-9]*)\s*\(([^)]*)\)\s*:", re.MULTILINE)

    for match in func_pat.finditer(active):
        func_name = match.group(1)
        params_str = match.group(2).strip()

        if not params_str:
            continue

        params = extract_params(params_str)
        # Skip parameters already suppressed with _
        params = [p for p in params if not p.startswith("_")]
        if not params:
            continue

        body = get_func_body(active, match.end())

        for param in params:
            # Check word-boundary usage in body
            if not re.search(r"\b" + param + r"\b", body):
                issues.append((func_name, param))

    return issues


def main():
    gd_files = list(SCRIPTS_DIR.rglob("*.gd"))
    if not gd_files:
        print(f"ERROR: No .gd files found under {SCRIPTS_DIR}", file=sys.stderr)
        sys.exit(1)

    all_issues = []
    for fp in sorted(gd_files):
        issues = check_file(fp)
        if issues:
            rel = fp.relative_to(SCRIPTS_DIR.parent)
            for func_name, param in issues:
                all_issues.append((str(rel), func_name, param))
                print(f"  UNUSED: {rel}::{func_name}() — unused: {param}")

    print(f"\n{'='*60}")
    if all_issues:
        print(f"FAILED: {len(all_issues)} unused parameter(s) found.")
        print("Prefix unused parameters with underscore (_) to suppress.")
        sys.exit(1)
    else:
        print(f"PASSED: No unused parameters in {len(gd_files)} script(s).")
        sys.exit(0)


if __name__ == "__main__":
    main()
