#!/usr/bin/env python3
"""Verify bracket balance and basic syntax sanity for the patched Dart files."""
import sys
from pathlib import Path

FILES = [
    "lib/core/services/auth_service.dart",
    "lib/core/services/student_service.dart",
    "lib/core/services/excel_import_service.dart",
    "lib/core/services/qr_enrollment_service.dart",
    "lib/core/services/password_hasher.dart",
    "test/core/services/auth_service_test.dart",
]

ROOT = Path("/home/z/my-project")


def check_balance(text: str, open_ch: str, close_ch: str) -> int:
    """Return imbalance (positive = too many opens, negative = too many closes).
    Strips strings and comments first to avoid false positives."""
    # Strip line comments
    out_lines = []
    in_block_comment = False
    for line in text.splitlines():
        if in_block_comment:
            idx = line.find("*/")
            if idx == -1:
                continue
            line = line[idx + 2:]
            in_block_comment = False
        # Walk character-by-character to handle //, /*, ', ", $
        result = []
        i = 0
        in_string = None
        while i < len(line):
            c = line[i]
            if in_string:
                if c == "\\" and i + 1 < len(line):
                    result.append(" ")
                    i += 2
                    continue
                if c == in_string:
                    in_string = None
                result.append(" ")
            else:
                if c == "/" and i + 1 < len(line) and line[i + 1] == "/":
                    break  # rest is line comment
                if c == "/" and i + 1 < len(line) and line[i + 1] == "*":
                    in_block_comment = True
                    break
                if c in ("'", '"'):
                    in_string = c
                    result.append(" ")
                else:
                    result.append(c)
            i += 1
        out_lines.append("".join(result))

    cleaned = "\n".join(out_lines)
    return cleaned.count(open_ch) - cleaned.count(close_ch)


def main():
    overall_ok = True
    for rel in FILES:
        path = ROOT / rel
        if not path.exists():
            print(f"MISSING: {rel}")
            overall_ok = False
            continue
        text = path.read_text(encoding="utf-8")
        parens = check_balance(text, "(", ")")
        braces = check_balance(text, "{", "}")
        brackets = check_balance(text, "[", "]")
        status = "OK" if (parens == 0 and braces == 0 and brackets == 0) else "FAIL"
        if status == "FAIL":
            overall_ok = False
        print(f"{status}  {rel}  parens={parens:+d}  braces={braces:+d}  brackets={brackets:+d}  lines={text.count(chr(10))}")
    print()
    print("PASS" if overall_ok else "FAIL")
    sys.exit(0 if overall_ok else 1)


if __name__ == "__main__":
    main()
