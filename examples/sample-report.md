# Mac disk report: 2026-10-20

> Example output with made-up data. Your report lists your own folders, versions and sizes.

**Disk:** 224 GB of 228 GB used, **4.5 GB free** (98% used).
**Scanned with:** Mole 1.44.1, Homebrew, Docker running.

> **Nothing was deleted.** This report only lists commands. Read each one before running it:
> `rm -rf` skips the Trash and cannot be undone. Sizes are estimates.
> In Claude Code you can run a command yourself with `! <command>`.

## Summary

| Group | Potential space |
| --- | ---: |
| Safe (rebuilds itself) | about 12 GB |
| Check first (may hold your work) | up to 24 GB |

Biggest items:

| # | Item | Size | Group |
| ---: | --- | ---: | --- |
| 1 | iOS simulators (Xcode is no longer installed) | 7.6 GB | Check first |
| 2 | Gradle caches | 4.1 GB | Safe |
| 3 | Docker build cache and unused images | 3.9 GB | Safe |
| 4 | Local (WordPress) sites | 3.6 GB | Check first |
| 5 | Android emulator images | 2.4 GB | Check first |

## Where the space goes

| Size | Location | What it is |
| ---: | --- | --- |
| 21 GB | `~/Library/Containers/com.docker.docker` | Docker Desktop disk image (images 6.9 GB, volumes 5.5 GB, build cache 3 GB) |
| 18 GB | `~/code/client-erp` | your project, with 4.8 GB of attachments and a 3.9 GB yarn cache |
| 11 GB | `~/Library/Application Support/Claude/vm_bundles` | Claude desktop app's VM image |
| 8.4 GB | `/opt/homebrew` | Homebrew formulae and casks |
| 7.6 GB | `~/Library/Developer/CoreSimulator`, `/Library/Developer/CoreSimulator` | iOS simulators |
| 4.5 GB | `~/.gradle` | Gradle caches and wrappers |

## 1. Safe to clean

These rebuild themselves; the cost is a re-download or a slower next build.

### 1.1 Docker build cache and unused images (about 3.9 GB)

Build cache (1.8 GB reclaimable) and images no container uses (2.2 GB). Images are pulled or rebuilt
again when a project needs them. Your volumes (5.5 GB) are all in use and are not touched.

```sh
# check
docker system df
# clean
docker builder prune -f
docker image prune -a -f
```

`Docker.raw` usually shrinks on its own after this; if not, restart Docker Desktop.

### 1.2 Gradle caches (about 4.1 GB)

Downloaded dependencies and build outputs; Gradle downloads them again on the next build.

```sh
# check
du -sh ~/.gradle/caches
# clean (stops Gradle first)
pkill -f GradleDaemon
rm -rf ~/.gradle/caches
```

### 1.3 Python package caches (about 2.9 GB)

Poetry's download cache (1.8 GB) and uv's cache (1.1 GB). Packages are downloaded again when needed.
Poetry's `virtualenvs` folder is not included: it holds your projects' environments (see 2.5).

```sh
# check
du -sh ~/Library/Caches/pypoetry/* ~/.cache/uv
# clean
rm -rf ~/Library/Caches/pypoetry/cache ~/Library/Caches/pypoetry/artifacts
uv cache clean
```

### 1.4 Mole's cleanup list (about 630 MB)

App caches, logs, an old Claude Code version and Homebrew downloads that Mole previewed.
The full list is in `~/.config/mole/clean-list.txt`.

```sh
# check
mo clean --dry-run
# clean
mo clean
```

### 1.5 VS Code updater leftovers (about 870 MB)

```sh
# check
du -sh ~/Library/Caches/com.microsoft.VSCode.ShipIt
# clean (quit VS Code first)
rm -rf ~/Library/Caches/com.microsoft.VSCode.ShipIt
```

## 2. Check first

These may hold work or data. Answer the question first, then run the commands you need.

### 2.1 iOS simulators (about 7.6 GB)

**Question:** Do you still build iOS apps? Xcode is no longer installed, so this is left over.

```sh
# check
du -sh ~/Library/Developer/CoreSimulator /Library/Developer/CoreSimulator
# clean
rm -rf ~/Library/Developer/CoreSimulator
sudo rm -rf /Library/Developer/CoreSimulator   # system-wide runtimes; needs your password
```

If the `sudo` line says "Resource busy", restart the Mac and run it again.
Keep `/Library/Developer/CommandLineTools`: git and Homebrew need it.

### 2.2 Android emulators and SDK data (about 2.4 GB)

**Question:** Do you still do Android work? Android Studio is not installed.

```sh
# check
du -sh ~/.android
# clean (also removes adb keys)
rm -rf ~/.android
```

### 2.3 Local (WordPress) sites (about 3.6 GB)

**Question:** Do you need any of these WordPress sites? The Local app is no longer installed.

```sh
# check
du -sh ~/Library/Application\ Support/Local/run/*
# clean
rm -rf ~/Library/Application\ Support/Local
```

### 2.4 Old Node versions (about 700 MB)

**Question:** Do any projects still need Node 12, 14 or 16? Your default is v22.18.0.

```sh
# check
source ~/.nvm/nvm.sh && nvm ls
# clean
nvm uninstall 12.18.0
nvm uninstall 14.0.0
nvm uninstall 14.15.0
nvm uninstall 16.20.1
```

### 2.5 Homebrew packages nothing depends on (about 900 MB)

**Question:** Do you use any of these directly: `go`, `ruby`, `lua@5.4`, `aspell`?
If you use one, keep it with `brew install <name>` before running autoremove.

```sh
# check
brew autoremove --dry-run
# clean
brew autoremove
brew cleanup --prune=all
```

### 2.6 OrbStack leftovers (about 320 MB)

**Question:** You use Docker Desktop (active context `desktop-linux`). Remove OrbStack?
The OrbStack app is already gone; Homebrew still lists the cask.

```sh
# check
docker context show
brew list --cask | grep orbstack
# clean
brew uninstall --cask --zap orbstack
docker context rm orbstack
rm -rf ~/.orbstack
```

### 2.7 Dotfolders of tools that are gone (about 370 MB)

Mole found no installed tool for these.

```sh
# check
du -sh ~/.antigravity ~/.codeium ~/.cursor-tutor
# clean
rm -rf ~/.antigravity ~/.codeium ~/.cursor-tutor
```

## 3. Leave alone

| Location | Size | Why |
| --- | ---: | --- |
| Docker volumes | 5.5 GB | all in use by containers (databases) |
| `~/Library/Application Support/Claude/vm_bundles` | 11 GB | Claude desktop downloads it again if removed; goes away only with the app |
| `/Library/Developer/CommandLineTools` | 1.7 GB | git, compilers and Homebrew need it |
| `/private/var/vm` | 2.0 GB | macOS swap and sleep image |

## After cleaning

```sh
df -h /System/Volumes/Data
```

Running everything in group 1 takes you from 4.5 GB to about 16 GB free; group 2 adds up to 24 GB.
Finder may show more free space than `df` because it counts purgeable space.

## How this was scanned

Read-only commands only: `scripts/scan.sh` (df, diskutil, du, find), `mo clean --dry-run`,
`mo purge --dry-run`, `docker system df`, `brew cleanup -n`, `brew autoremove --dry-run`.
`~/.Trash` was not readable (the terminal has no Full Disk Access).
