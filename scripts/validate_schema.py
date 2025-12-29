"""
Validate that schema/001_init.sql can be executed by the current Python+SQLite.

Usage:
  python scripts/validate_schema.py
"""

from __future__ import annotations

import pathlib
import sqlite3
import sys


def main() -> int:
    schema_path = pathlib.Path(__file__).resolve().parents[1] / "schema" / "001_init.sql"
    schema = schema_path.read_text(encoding="utf-8")

    conn = sqlite3.connect(":memory:")
    conn.execute("PRAGMA foreign_keys=ON;")

    # Strip '-- ...' comments first so we can split safely on ';'
    # (This repository's schema does not use semicolons inside string literals.)
    no_comments_lines: list[str] = []
    for line in schema.splitlines():
        if "--" in line:
            line = line.split("--", 1)[0]
        no_comments_lines.append(line)
    no_comments = "\n".join(no_comments_lines)
    statements = [s.strip() for s in no_comments.split(";") if s.strip()]

    try:
        for i, stmt in enumerate(statements, start=1):
            try:
                conn.execute(stmt)
            except Exception as e:
                print(f"\nFAILED statement #{i}:\n{stmt}\n", file=sys.stderr)
                raise
        print(f"OK (SQLite {sqlite3.sqlite_version})")
        return 0
    except Exception as e:
        print(f"ERROR: {e} (SQLite {sqlite3.sqlite_version})", file=sys.stderr)
        return 1
    finally:
        conn.close()


if __name__ == "__main__":
    raise SystemExit(main())


