param(
  [string]$DbPath = (Join-Path $PSScriptRoot "..\data\health.db")
)

$ErrorActionPreference = "Stop"

$SchemaPath = (Join-Path $PSScriptRoot "..\schema\001_init.sql")

if (-not (Test-Path $SchemaPath)) {
  throw "Schema file not found: $SchemaPath"
}

$DbDir = Split-Path -Parent $DbPath
if (-not (Test-Path $DbDir)) {
  New-Item -ItemType Directory -Force -Path $DbDir | Out-Null
}

function Init-WithSqlite3 {
  param([string]$Db, [string]$Schema)
  & sqlite3 $Db ".read $Schema"
}

function Init-WithPython {
  param([string]$Db, [string]$Schema)
  $py = @"
import sqlite3, pathlib
db = pathlib.Path(r'''$Db''')
schema = pathlib.Path(r'''$Schema''').read_text(encoding='utf-8')
conn = sqlite3.connect(db)
try:
    conn.executescript(schema)
    conn.commit()
finally:
    conn.close()
"@
  & python -c $py
}

if (Get-Command sqlite3 -ErrorAction SilentlyContinue) {
  Init-WithSqlite3 -Db $DbPath -Schema $SchemaPath
  Write-Host "Initialized: $DbPath (via sqlite3)"
  exit 0
}

if (Get-Command python -ErrorAction SilentlyContinue) {
  Init-WithPython -Db $DbPath -Schema $SchemaPath
  Write-Host "Initialized: $DbPath (via python)"
  exit 0
}

throw "Neither 'sqlite3' nor 'python' found in PATH. Install one of them, then rerun this script."


