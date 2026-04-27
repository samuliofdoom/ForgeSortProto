#!/bin/bash
# GDScript Validation Script for Godot Projects
# Run: ./validate.sh

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

ERRORS=0

echo "=== GDScript Validation ==="

# Check 1: connect() calls have matching _on_ handlers in same file
echo "Checking signal handlers..."
for f in $(find scripts -name "*.gd"); do
    # Get signal connections (patterns like .connect(_on_signal))
    connections=$(grep -oP '\.connect\(\K[_a-zA-Z][_a-zA-Z0-9]*' "$f" 2>/dev/null || true)
    if [[ -n "$connections" ]]; then
        for handler in $connections; do
            # Only check handlers that start with _on_
            if [[ "$handler" == "_on_"* ]]; then
                if ! grep -q "func $handler" "$f" 2>/dev/null; then
                    echo "  ERROR: $f connects to '$handler' but handler not found in file"
                    ERRORS=$((ERRORS + 1))
                fi
            fi
        done
    fi
done

# Check 2: Scene file load_steps consistency
echo "Checking scene structure..."
if [[ -f "scenes/Main.tscn" ]]; then
    load_steps=$(grep "load_steps=" scenes/Main.tscn | grep -oP 'load_steps=\K[0-9]+' | head -1)
    ext_count=$(grep -c '\[ext_resource' scenes/Main.tscn)
    sub_count=$(grep -c '\[sub_resource' scenes/Main.tscn)
    total=$((ext_count + sub_count))

    echo "  Main.tscn: load_steps=$load_steps, ext=$ext_count, sub=$sub_count"

    if [[ "$load_steps" != "$total" ]]; then
        echo "  ERROR: load_steps=$load_steps but ext+sub=$total"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for duplicate IDs
    ext_ids=$(grep 'id="' scenes/Main.tscn | grep -oP 'id="\K[^"]+' | sort)
    dup=$(echo "$ext_ids" | uniq -d | wc -l)
    if [[ "$dup" -gt 0 ]]; then
        echo "  ERROR: Duplicate IDs found in Main.tscn"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Check 3: All referenced scripts exist
echo "Checking script references..."
for f in $(find scripts -name "*.gd"); do
    class_name=$(grep -oP 'class_name \K[A-Z][A-Za-z]*' "$f" 2>/dev/null || true)
    if [[ -n "$class_name" ]]; then
        if ! grep -rq "class_name $class_name" scripts/; then
            echo "  WARN: $f declares class_name $class_name but not found"
        fi
    fi
done

# Check 4: Autoload nodes exist
echo "Checking autoloads..."
if [[ -f "project.godot" ]]; then
    autoloads=$(grep -A20 '\[autoload\]' project.godot | grep -oP '^\s*\K[A-Za-z]+="\*/[^*]+\*"' | sed 's/.*"\/\*res:\/\/\(.*\)\.gd".*/\1/' | tr -d '*' || true)
    for path in $autoloads; do
        full_path="scripts/${path}.gd"
        if [[ ! -f "$full_path" ]]; then
            echo "  ERROR: Autoload references $full_path which does not exist"
            ERRORS=$((ERRORS + 1))
        fi
    done
fi

# Summary
echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo "=== Validation PASSED ==="
    exit 0
else
    echo "=== Validation FAILED: $ERRORS errors ==="
    exit 1
fi
