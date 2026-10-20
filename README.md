# mac-disk-report

An agent skill (for Claude Code and other agents that read `SKILL.md` folders) that finds out what is
filling your Mac's disk and writes **one Markdown report** with copy-paste commands to get the space back.

**It never deletes anything.** The skill runs only read-only commands and dry runs; every cleanup command
goes into the report, and you decide which ones to run.

```text
You:     my mac is almost full, what can I clean?
Agent:   (runs a read-only scan for a few minutes)
         Report saved to ~/Desktop/mac-disk-report-2026-10-20.md
         4.5 GB free. Safe to clean: about 12 GB. Check first: up to 30 GB.
         Biggest: Docker build cache 3 GB, Gradle caches 4 GB, iOS simulators 7.6 GB.
         Nothing was deleted.
```

## What it checks

- Disk totals (`df`, `diskutil`) and the biggest folders in your home, `~/Library`, `/Applications`
- Developer caches: Xcode, iOS simulators, Android/Gradle, npm/Yarn/pnpm, pip/uv/Poetry/conda, Go, Cargo,
  Maven, CocoaPods, Playwright, Hugging Face, Ollama
- Old runtime versions: nvm, pyenv, rbenv, rustup
- Docker: images, build cache, unused volumes, stopped containers, the Docker Desktop disk image;
  other VM tools (OrbStack, Colima, Lima, UTM, Parallels)
- Homebrew: old versions, unneeded dependencies, casks whose app was deleted
- [Mole](https://github.com/tw93/mole) previews, if installed (`mo clean --dry-run`, `mo purge --dry-run`):
  app caches, logs, leftover files, orphan dotfolders
- Files over 1 GB, old installers (`.dmg`, `.pkg`, `.iso`), forgotten `node_modules` and `.venv` folders,
  Time Machine local snapshots

The report sorts everything into three groups:

| Group | Meaning |
| --- | --- |
| **Safe** | caches and build output that rebuild themselves |
| **Check first** | may hold your work (VMs, simulators, old projects, Docker volumes); each has a question to answer first |
| **Leave alone** | managed by macOS or needed by other tools, with the reason |

Each item has a size, what it is, what you lose, a **check** command and a **clean** command.
See [examples/sample-report.md](examples/sample-report.md).

## Safety

- The scanner (`scripts/scan.sh`) runs only `df`, `diskutil info`, `du`, `find` (no `-delete`/`-exec`), `ls`,
  `stat`, `tmutil listlocalsnapshots`, read-only `docker` and `brew` commands, `brew cleanup -n`,
  `brew autoremove --dry-run`, `mo clean --dry-run` and `mo purge --dry-run`. Read it: it is one short file.
- The skill tells the agent never to run `rm`, `prune`, `uninstall`, `mo clean` (without `--dry-run`),
  `sudo` or anything else that changes files, even if you ask it to; it points you to the command instead.
- The only file written during a scan is Mole's own preview list, `~/.config/mole/clean-list.txt`
  (only if Mole is installed), plus the report itself.
- Homebrew runs with `HOMEBREW_NO_AUTO_UPDATE=1`, so the scan does not update anything.
- iCloud Drive and `~/Library/CloudStorage` are skipped so the scan never touches cloud files.
- Paths and sizes stay on your Mac; nothing is uploaded by the scanner. (Your agent sees the scan, as with
  any file it reads.)

## Requirements

- macOS (tested on macOS 27, Apple Silicon); works with the built-in `/bin/bash` and `perl`
- Optional, used when present: [Mole](https://github.com/tw93/mole) (`brew install mole`), Homebrew,
  Docker, Xcode (`xcrun`), `python3`

## Install

**Claude Code, for all your projects:**

```sh
git clone https://github.com/zeel-codder/mac-disk-report ~/.claude/skills/mac-disk-report
```

**Claude Code, for one project** (shared with your team through git):

```sh
git clone https://github.com/zeel-codder/mac-disk-report .claude/skills/mac-disk-report
```

**Other agents:** copy the folder wherever your agent loads `SKILL.md` skills from.

Update later with `git -C ~/.claude/skills/mac-disk-report pull`.

## Use

Ask in plain words; the skill triggers on things like:

- "my mac is full, what can I clean?"
- "why is System Data 80 GB?"
- "free up disk space but don't delete anything yet"
- "how much space are Docker and Xcode using?"
- "/mac-disk-report"

The agent tells you it is starting a read-only scan (3-10 minutes). macOS may ask whether your terminal
may access some folders; you can decline, and those folders are reported as unreadable. Give the terminal
Full Disk Access (System Settings > Privacy & Security) for a complete scan.

The report is saved to `~/Desktop/mac-disk-report-YYYY-MM-DD.md` unless you ask for another place.

### Without an agent

The scanner works on its own and prints the raw findings as Markdown:

```sh
bash scripts/scan.sh > ~/Desktop/mac-disk-scan.md
bash scripts/scan.sh --fast      # skip the slow whole-home searches
bash scripts/scan.sh --no-mole   # skip Mole even if installed
```

The agent's value on top is identifying unknown folders, picking the right command for each item from
[references/cleanup-catalog.md](references/cleanup-catalog.md) and writing it up.

## How it works

```text
mac-disk-report/
├── SKILL.md                         # instructions the agent follows (workflow, report-only rule)
├── scripts/scan.sh                  # read-only scanner, prints Markdown
├── references/cleanup-catalog.md    # what each location is, its group, check and clean commands
├── assets/report-template.md        # the report layout
└── examples/sample-report.md        # an example report (made-up data)
```

1. The agent runs `scripts/scan.sh` and reads its output.
2. It probes anything large the catalog doesn't explain (read-only `du`/`ls`).
3. It classifies each item with the catalog and fills in the template.
4. It saves the report and gives you a short summary in chat.

## Contributing

Ideas and fixes are welcome, especially new locations and better commands.

- **New location:** add a line to the "Known locations" list in `scripts/scan.sh` and a row to
  `references/cleanup-catalog.md` with its group, check and clean command, and what you lose.
- **Keep the scanner read-only.** No `rm`, `mv`, `-delete`, `-exec`, `prune`, `sudo`, or cleanup
  commands without their dry-run flag. A quick check before a pull request:

  ```sh
  bash -n scripts/scan.sh
  grep -nE '\brm |\bmv |-delete|-exec |[a-z] prune|sudo' scripts/scan.sh   # should only match comments
  bash scripts/scan.sh --fast > /tmp/scan.md && head -40 /tmp/scan.md
  ```
- Prefer each tool's own cleanup command over `rm -rf`, and never wildcard a whole `~/Library` folder.
- Test on a real Mac and say which macOS version in the pull request.

## Licence

[MIT](LICENSE)
