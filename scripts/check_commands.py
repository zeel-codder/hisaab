#!/usr/bin/env python3
"""Check that a report's commands are paste-safe in any macOS terminal.

Checks every shell code block (```sh, ```bash, ```zsh, ```shell) and every inline `command` in a
table's Check or Clean column (the cleanup catalog keeps its commands there). Each one must have no
`#` comments (stock zsh passes them to the command as arguments) and must parse in both `zsh -f -n`
and `bash -n`. Parsing only: nothing is executed. Placeholder blocks like `<check command>` in the
template are reported too; in table cells a `<placeholder>` is read as a plain word.

Usage: python3 scripts/check_commands.py report.md [more.md ...]
"""
import re
import shutil
import subprocess
import sys

FENCE = re.compile(r"^```(?:sh|bash|zsh|shell)[ \t]*\n(.*?)^```", re.S | re.M)
COMMAND_COLUMNS = {"check", "clean"}

shells = [s for s in (["zsh", "-f", "-n"], ["bash", "-n"]) if shutil.which(s[0])]
for name in ("zsh", "bash"):
    if not any(s[0] == name for s in shells):
        print(f"warning: {name} not found, commands were not checked with it")
if not shells:
    sys.exit(2)


def cells(row):
    return [c.strip() for c in row.strip().strip("|").split("|")]


def table_commands(text):
    """Yield (line number, command) for inline code in the Check and Clean columns of tables."""
    columns = []
    for number, line in enumerate(text.splitlines(), 1):
        if not line.lstrip().startswith("|"):
            columns = []
            continue
        row = cells(line)
        if not columns:
            columns = [c.lower() for c in row]
            continue
        for column, cell in zip(columns, row):
            if column in COMMAND_COLUMNS:
                for command in re.findall(r"`([^`]+)`", cell):
                    yield number, re.sub(r"<[^<>]+>", "X", command)


def check(path, where, command):
    found = 0
    for line in command.splitlines():
        if re.search(r"(^|\s)#", line):
            print(f"{path}: {where}: '#' comment: {line.strip()}")
            found += 1
    for shell in shells:
        result = subprocess.run(shell, input=command + "\n", text=True, capture_output=True)
        if result.returncode:
            print(f"{path}: {where}: {shell[0]} cannot parse it: {result.stderr.strip()}")
            found += 1
    return found


problems = checked = 0
for path in sys.argv[1:]:
    text = open(path, encoding="utf-8").read()
    for number, block in enumerate(FENCE.findall(text), 1):
        problems += check(path, f"block {number}", block)
        checked += 1
    for number, command in table_commands(text):
        problems += check(path, f"line {number}", command)
        checked += 1
print(f"{checked} command(s) checked, {problems} problem(s)")
sys.exit(1 if problems else 0)
