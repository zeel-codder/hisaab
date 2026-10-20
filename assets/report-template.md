# Mac disk report: <YYYY-MM-DD>

**Disk:** <used> GB of <total> GB used, **<free> GB free** (<pct>% used).
**Scanned with:** <Mole x.y.z | du/df only>, <Homebrew>, <Docker running | Docker not running | no Docker>.

> **Nothing was deleted.** This report only lists commands. Read each one before running it:
> `rm -rf` skips the Trash and cannot be undone. Sizes are estimates.
> Commands work in zsh and bash; paste one line at a time. In Claude Code you can run one with `! <command>`.

## Summary

| Group | Potential space |
| --- | ---: |
| Safe (rebuilds itself) | about <n> GB |
| Check first (may hold your work) | up to <n> GB |

Biggest items:

| # | Item | Size | Group |
| ---: | --- | ---: | --- |
| 1 | <item> | <size> | Safe / Check first / Leave alone |

## Where the space goes

| Size | Location | What it is |
| ---: | --- | --- |
| <size> | `<path>` | <one line> |

## 1. Safe to clean

These rebuild themselves; the cost is a re-download or a slower next build.

### 1.1 <Item> (about <size>)

<What it is, and what happens after cleaning. Quit <app> first, if needed.>

Check:

```sh
<check command>
```

Clean:

```sh
<cleanup command>
```

## 2. Check first

These may hold work or data. Answer the question first, then run the commands you need.

### 2.1 <Item> (about <size>)

**Question:** <Do you still ...?>

<What it is and what you lose.>

Check:

```sh
<check command>
```

Clean:

```sh
<cleanup command>
```

## 3. Leave alone

| Location | Size | Why |
| --- | ---: | --- |
| `<path>` | <size> | <reason> |

## After cleaning

```sh
df -h /System/Volumes/Data
```

<Notes: e.g. Docker's disk image shrinks after pruning, restart Docker Desktop if it doesn't; Finder's
free space can differ from df because of purgeable space.>

## How this was scanned

Read-only commands only: <list, e.g. scan.sh, mo clean --dry-run, mo purge --dry-run, docker system df,
brew cleanup -n>. <Folders that were not readable, sections that timed out.>
