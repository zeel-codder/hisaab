---
name: hisaab
description: >-
  Scan a Mac's disk usage end to end (uses Mole `mo` if installed, plus du, df, Docker, Homebrew and
  dev-tool caches) and write ONE Markdown report that explains what is using space and gives copy-paste
  cleanup commands grouped by risk. Report-only: it never deletes anything or runs a cleanup command.
  Use this whenever someone says their Mac is full or low on storage, "System Data" is huge, wants to
  free up disk space, asks what is taking space, wants to clean caches, Docker, Xcode, simulators,
  Gradle, node_modules or old Node/Python versions, or mentions Mole / `mo clean`, even if they don't
  ask for a "report".
compatibility: macOS only. Needs /bin/bash and perl (both ship with macOS). Optional, used when present - mo (Mole), brew, docker, xcrun, python3.
---

# hisaab: Mac disk report

*Hisaab* (Hindi, "the accounts") keeps the books on a Mac's disk; it never spends anything.

Produce one Markdown report that tells the person where their disk space went and gives them the exact
commands to get it back, ordered by how safe they are. The person runs the commands themselves.

## The one rule: report only

Do not run any command that deletes, moves, prunes, uninstalls or "cleans" anything. Not during the scan,
not to "test" a command, not to make the numbers nicer, not as a final step, and not if a tool offers to
do it for you. Every cleanup command goes into the report for the person to run.

Why: deletes on a Mac are permanent (`rm -rf` skips the Trash), the scan can't know which folders hold
someone's only copy of work, and people use this skill precisely because they want to review before
anything is touched. If the person asks you to run something from the report, say this skill is
report-only and point them to the command; in Claude Code they can run it themselves by typing
`! <command>`.

Allowed (read-only): `scripts/scan.sh`, `scripts/check_commands.py`, `df`, `diskutil info|list`, `du`, `ls`, `stat`, `file`, `find`
without `-delete`/`-exec`, `tmutil listlocalsnapshots`, `docker system df|images|ps|volume ls|info`,
`brew list|info|leaves|cleanup -n|autoremove --dry-run`, `mo clean --dry-run`, `mo purge --dry-run`,
`mo analyze --json <path>`, `xcrun simctl list`, `<tool> --version`, reading small text files such as a
README to identify a folder.

Never run: `rm`, `mv`, `trash`, `srm`, any `prune`/`clean`/`purge`/`uninstall`/`delete`/`autoremove`
without its dry-run flag, `mo clean` / `mo purge` / `mo uninstall` / `mo optimize` without `--dry-run`,
`mo installer` (its dry run opens an interactive picker), `mo analyze` without `--json` (interactive),
`tmutil deletelocalsnapshots`, `sudo` anything, or `osascript` that empties the Trash.

Privacy: the report lists paths and sizes only. Don't open or quote file contents beyond what you need to
name a folder, and never read `.env`, keychains, SSH keys or browser profiles.

## Workflow

1. **Ask where to save the report, before scanning.** Don't pick a place yourself: a report dropped
   into whatever folder you happen to be in (often someone's project repo) ends up committed or lost.
   Offer the default, this skill's own `reports/` folder (git-ignored, so reports never get pushed with the
   skill), and let them name any other folder. Skip the question only if they already said where.
   Ask it together with what will happen: a read-only scan of about 3-10 minutes, during which macOS may
   ask whether the terminal can access some folders (they can say no; those show as unreadable).

2. **Run the scanner** (from this skill's folder; use a long timeout, around 10 minutes):

   ```sh
   bash <skill-dir>/scripts/scan.sh > "${TMPDIR:-/tmp}/hisaab-scan.md"
   ```

   Options: `--fast` skips the two whole-home searches (files over 1 GB, `node_modules`/`.venv`);
   `--no-mole` skips Mole. The script detects Mole, Homebrew and Docker on its own; without Mole it still
   covers everything except Mole's app-cache and leftover-file checks.

3. **Read the scan** (`${TMPDIR:-/tmp}/hisaab-scan.md`). Note the free space and the biggest items.

4. **Explain every big item.** For anything over roughly 1 GB that the catalog doesn't cover, find out
   what it is with read-only probes (`du -sh <dir>/*`, `ls`, a README, the owning app). A folder you
   can't identify goes under "Check first", never "Safe".

5. **Classify** each item with `references/cleanup-catalog.md`, which has the command, what it is and what
   the person loses for common locations. Three groups:
   - **Safe**: caches and build output that rebuild themselves; the cost is a slower next build or a
     re-download.
   - **Check first**: could hold work or data (VMs, simulators, emulators, old runtimes, Docker volumes,
     project folders, Downloads, backups, apps' data). Phrase each as a question the person can answer.
   - **Leave alone**: managed by macOS or needed by other tools (swap, Command Line Tools, Photos, iCloud,
     in-use Docker volumes). Say why so nobody deletes them by hand.

6. **Write the report** using `assets/report-template.md`, as `hisaab-YYYY-MM-DD.md` in the
   folder the person chose in step 1 (default `<skill-dir>/reports/`; create that folder if needed).
   Write nothing anywhere else. One report per run; if that file already exists, add the time
   (`-HHMM`) instead of overwriting it.
   Then check the commands: `python3 <skill-dir>/scripts/check_commands.py <report>`. It only parses
   each block with zsh and bash (runs nothing) and flags `#` comments. Fix what it reports and rerun it
   until it says `0 problem(s)`. If `xcode-select -p` fails, `/usr/bin/python3` is only a stub that opens
   an install dialog: don't run it; check each block yourself with `zsh -f -n` and `bash -n` instead.

7. **Reply in chat** with: free space now, the potential gain from "Safe" and from "Check first", the top
   three items, and the report's path. Remind them nothing was deleted and that they run the commands.

## Writing the commands

- Give each item a **check** command (`du -sh <path>`, `docker system df`, `nvm ls`...) before the cleanup
  command, so the person sees the size and target first.
- Prefer the tool's own cleanup over `rm -rf`: `brew cleanup`, `npm cache clean --force`, `uv cache clean`,
  `docker builder prune`, `xcrun simctl delete unavailable`, `nvm uninstall <version>`. Use `rm -rf` only
  for plain cache folders with no tool command, and always with the full quoted path, never a wildcard
  at the top of a folder like `~/Library/*`.
- Name the exact things to remove (versions, image names, folder paths) using what the scan found, not
  generic placeholders, when the scan has the data.
- Mark commands that need `sudo` and say why; say when an app should be quit first (Docker, Xcode,
  Android Studio, the app whose cache it is).
- Put risky or optional variants in their own block with a sentence above it, e.g. "`docker volume
  prune` deletes data".

### Paste-safe in anyone's terminal

The report is for the person who ran the scan, so use their real versions, image names and folders. But
every command has to work when pasted into a plain macOS terminal: stock zsh (the default shell), bash,
Intel or Apple Silicon, with or without Oh My Zsh.

- **No `#` comments inside command blocks.** Stock zsh does not treat `#` as a comment when you type or
  paste, so `rm -rf ~/x   # old cache` would also delete files named `#`, `old` and `cache` in the current
  folder, and a `# check` line fails with "command not found". Put every note in prose above the block.
- Use two blocks per item, introduced by **Check:** and **Clean:** in prose (see the template).
- Write home paths as `~/...` or `"$HOME/..."`, never `/Users/<name>/...`. Put paths with spaces in
  double quotes: `rm -rf "$HOME/Library/Application Support/Postman"`. A `~` inside quotes does not
  expand, so inside quotes use `$HOME`.
- Homebrew lives in `/opt/homebrew` on Apple Silicon and `/usr/local` on Intel: write `"$(brew --prefix)"`
  rather than either path.
- Only give commands for tools the scan found installed. If a tool needs setting up in a fresh terminal,
  include that line; `nvm` is a shell function, so start with `. "${NVM_DIR:-$HOME/.nvm}/nvm.sh"`.
- No wildcards in cleanup commands (an unmatched glob is an error in zsh and a literal name in bash);
  name each path. No shell-specific syntax (zsh globs like `(N)` or `**`, bash-only `[[ ]]` in one-liners).
- One command per line, so the person can run them one at a time and stop.
- Avoid double counting in totals: `~/Library/Containers/com.docker.docker` already contains Docker's
  images, volumes and build cache; Homebrew's Caskroom overlaps with installed apps; Mole's preview
  overlaps with caches you list separately.
- Sizes are estimates; round them ("about 4 GB").

## When things are missing

- **No Mole**: say so in the report and suggest `brew install mole` as optional for a deeper scan; the
  report is still complete without it.
- **Docker installed but not running**: report the disk image size from the scan and tell them to start
  Docker and rerun for image and volume detail. Never start or stop Docker yourself.
- **No Xcode.app** (the scan says so): don't give `xcrun simctl` commands; the Command Line Tools alone
  don't include `simctl`.
- **Mole skipped as too old** (its help doesn't list the dry runs): suggest `brew upgrade mole`; never run
  an old Mole's `clean` or `purge`.
- **Not macOS**: stop and say the skill only supports macOS.
- **Scanner timed out on a section**: say which, and suggest `--fast` or a rerun.
