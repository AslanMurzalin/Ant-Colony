#!/usr/bin/env python3
"""
Contracts Verification Tool for Ant Colony
Validates that all GDScript functions, signals, and class names
declared across the project are properly documented in Contracts.md.
"""

import os
import re
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent.parent
CONTRACTS_FILE = ROOT_DIR / "Contracts.md"
SCRIPTS_DIR = ROOT_DIR / "scripts"

FUNC_PATTERN = re.compile(r"^\s*func\s+([a-zA-Z0-9_]+)\s*\(", re.MULTILINE)
SIGNAL_PATTERN = re.compile(r"^\s*signal\s+([a-zA-Z0-9_]+)\s*(\(|$)", re.MULTILINE)
CLASS_PATTERN = re.compile(r"^\s*class_name\s+([a-zA-Z0-9_]+)", re.MULTILINE)

# Functions that don't need dedicated contract entries (standard Godot virtual callbacks)
GODOT_VIRTUALS = {
    "_ready", "_process", "_physics_process", "_enter_tree",
    "_exit_tree", "_input", "_unhandled_input", "_draw", "_init"
}

def verify_contracts() -> bool:
    if not CONTRACTS_FILE.exists():
        print(f"❌ Error: {CONTRACTS_FILE} does not exist!")
        return False

    with open(CONTRACTS_FILE, "r", encoding="utf-8") as f:
        contracts_content = f.read()

    if not SCRIPTS_DIR.exists():
        print("ℹ️ No 'scripts/' directory found yet. Contracts are ahead of code (Clean state).")
        return True

    missing_items = []
    total_checked = 0

    for gd_file in SCRIPTS_DIR.rglob("*.gd"):
        if ".godot" in gd_file.parts:
            continue
        
        rel_path = gd_file.relative_to(ROOT_DIR)
        with open(gd_file, "r", encoding="utf-8") as f:
            code = f.read()

        # Check functions
        for match in FUNC_PATTERN.finditer(code):
            func_name = match.group(1)
            if func_name in GODOT_VIRTUALS:
                continue
            total_checked += 1
            if func_name not in contracts_content:
                missing_items.append((rel_path, "function", func_name))

        # Check signals
        for match in SIGNAL_PATTERN.finditer(code):
            sig_name = match.group(1)
            total_checked += 1
            if sig_name not in contracts_content:
                missing_items.append((rel_path, "signal", sig_name))

        # Check classes
        for match in CLASS_PATTERN.finditer(code):
            cls_name = match.group(1)
            total_checked += 1
            if cls_name not in contracts_content:
                missing_items.append((rel_path, "class", cls_name))

    if missing_items:
        print("\n🚨 CONTRACT VERIFICATION FAILED! 🚨")
        print("Humans are flesh and forget, but AI Agents must never forget!")
        print(f"Found {len(missing_items)} item(s) missing from Contracts.md:\n")
        for file_path, item_type, name in missing_items:
            print(f"  ❌ [{item_type.upper()}] '{name}' in '{file_path}' is NOT in Contracts.md!")
        print("\n👉 Remedy: Immediately add these signatures to Contracts.md before proceeding!\n")
        return False
    else:
        print(f"\n✅ All {total_checked} declared functions, signals, and classes are verified in Contracts.md!")
        return True

if __name__ == "__main__":
    success = verify_contracts()
    sys.exit(0 if success else 1)
