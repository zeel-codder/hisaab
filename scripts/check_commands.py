#!/usr/bin/env python3
"""Check that a report's commands are paste-safe in any macOS terminal.

For every ```sh block in the given Markdown files: no `#` comments (stock zsh passes them to the
command as arguments) and the block must parse in both `zsh -f -n` and `bash -n`. Parsing only:
nothing is executed. Placeholder blocks like `<check command>` in the template are reported too.

Usage: python3 scripts/check_commands.py report.md [more.md ...]
"""
import re
import shutil
import subprocess
import sys

shells = [s for s in (["zsh", "-f", "-n"], ["bash", "-n"]) if shutil.which(s[0])]
problems = 0
for path in sys.argv[1:]:
    text = open(path, encoding="utf-8").read()
    for number, block in enumerate(re.findall(r"```sh\n(.*?)```", text, re.S), 1):
        for line in block.splitlines():
            if re.search(r"(^|\s)#", line):
                print(f"{path}: block {number}: '#' comment: {line.strip()}")
                problems += 1
        for shell in shells:
            result = subprocess.run(shell, input=block, text=True, capture_output=True)
            if result.returncode:
                print(f"{path}: block {number}: {shell[0]} cannot parse it: {result.stderr.strip()}")
                problems += 1
print(f"{problems} problem(s)")
sys.exit(1 if problems else 0)
