# Mac disk report: 2026-10-20

> Example output with made-up data. Your report lists your own folders, versions and sizes.

**Disk:** 238 GB of 245 GB used, **7.1 GB free** (97% used).
**Scanned with:** Mole 1.44.1, Homebrew, Docker running.

> **Nothing was deleted.** This report only lists commands. Read each one before running it:
> `rm -rf` skips the Trash and cannot be undone. Sizes are estimates.
> Commands work in zsh and bash; paste one line at a time. In Claude Code you can run one with `! <command>`.

## Summary

| Group | Potential space |
| --- | ---: |
| Safe (rebuilds itself) | about 28 GB |
| Check first (may hold your work) | up to 25 GB |

Biggest items:

| # | Item | Size | Group |
| ---: | --- | ---: | --- |
| 1 | Xcode DerivedData | 18 GB | Safe |
| 2 | iOS simulator runtimes you no longer target | 11 GB | Check first |
| 3 | Old installers in Downloads | 5.2 GB | Check first |
| 4 | Docker build cache | 4.1 GB | Safe |
| 5 | Homebrew old versions and downloads | 2.9 GB | Safe |

## Where the space goes

| Size | Location | What it is |
| ---: | --- | --- |
| 41 GB | `~/Library/Developer` | Xcode build products, simulators, device symbols |
| 34 GB | `~/Library/Containers/com.docker.docker` | Docker Desktop disk image: images 14 GB, volumes 9 GB, build cache 6 GB |
| 22 GB | `~/Pictures/Photos Library.photoslibrary` | Photos |
| 9.8 GB | `~/Downloads` | 5.2 GB of it is installers |
| 6.4 GB | `$(brew --prefix)` | Homebrew formulae and casks |
| 3.1 GB | `~/.nvm` | 6 Node versions |

## 1. Safe to clean

These rebuild themselves; the cost is a re-download or a slower next build.

### 1.1 Xcode DerivedData (about 18 GB)

Build products for every project you have opened. Xcode rebuilds them; the next build of each project is
slower. Quit Xcode first.

Check:

```sh
du -sh ~/Library/Developer/Xcode/DerivedData
```

Clean:

```sh
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### 1.2 Docker build cache (about 4.1 GB)

Layers kept to speed up `docker build`. The next build of each image is slower. Your images and volumes
are not touched.

Check:

```sh
docker system df
```

Clean:

```sh
docker builder prune -f
```

`Docker.raw` usually shrinks on its own afterwards; if not, restart Docker Desktop.

### 1.3 Homebrew old versions and downloads (about 2.9 GB)

Check:

```sh
brew cleanup -n
```

Clean:

```sh
brew cleanup --prune=all
```

### 1.4 npm and pip caches (about 2.6 GB)

Check:

```sh
du -sh ~/.npm "$(pip3 cache dir)"
```

Clean:

```sh
npm cache clean --force
pip3 cache purge
```

## 2. Check first

These may hold work or data. Answer the question first, then run the commands you need.

### 2.1 iOS simulator runtimes (about 11 GB)

**Question:** Do you still test on iOS 17 and iOS 18? Your projects target iOS 26.

Check:

```sh
xcrun simctl runtime list
```

Clean (use the identifiers the list shows for iOS 17.5 and 18.6):

```sh
xcrun simctl runtime delete 4B2C6F0E-7A1D-4E39-9C2B-1F5A8D3E6C70
xcrun simctl runtime delete 9E1D3A7B-2C4F-4B8E-A6D1-7F3C5B9E2A10
```

### 2.2 Old installers in Downloads (about 5.2 GB)

**Question:** Are these apps already installed? Then the installers are not needed.

| Size | File |
| ---: | --- |
| 3.1 GB | `~/Downloads/Xcode_26.xip` |
| 1.4 GB | `~/Downloads/ubuntu-24.04-desktop-arm64.iso` |
| 0.7 GB | `~/Downloads/Figma.dmg` |

Check:

```sh
ls -lh ~/Downloads/Xcode_26.xip ~/Downloads/ubuntu-24.04-desktop-arm64.iso ~/Downloads/Figma.dmg
```

Clean: move them to the Trash in Finder, or

```sh
rm ~/Downloads/Xcode_26.xip
rm ~/Downloads/ubuntu-24.04-desktop-arm64.iso
rm ~/Downloads/Figma.dmg
```

### 2.3 Old Node versions (about 1.9 GB)

**Question:** Does any project still need Node 16 or 18? Your default is v24.

Check:

```sh
. "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
nvm ls
```

Clean:

```sh
. "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
nvm uninstall 16.20.2
nvm uninstall 18.20.4
```

### 2.4 Docker volumes no container uses (about 3.8 GB)

**Question:** Do you still need the data in these? `docker volume rm` deletes it for good.

| Size | Volume |
| ---: | --- |
| 3.1 GB | `shop_mysql-data` |
| 0.7 GB | `blog_pg-data` |

Check:

```sh
docker volume ls -f dangling=true
```

Clean:

```sh
docker volume rm shop_mysql-data
docker volume rm blog_pg-data
```

### 2.5 Docker images no container uses (about 3.4 GB)

**Question:** Did you make any of these yourself, with `docker commit` or a local build whose Dockerfile
is gone? Those can't be pulled again. The others are pulled again when a project needs them.

| Size | Image | Created |
| ---: | --- | --- |
| 1.6 GB | `shop-api:dev` | 5 months ago |
| 1.1 GB | `postgres:14` | 8 months ago |
| 0.7 GB | `node:18-alpine` | 1 year ago |

Check:

```sh
docker images
```

Clean (only the ones you answered "no" for):

```sh
docker rmi shop-api:dev
docker rmi postgres:14
docker rmi node:18-alpine
```

`Docker.raw` usually shrinks on its own afterwards; if not, restart Docker Desktop.

## 3. Leave alone

| Location | Size | Why |
| --- | ---: | --- |
| `~/Pictures/Photos Library.photoslibrary` | 22 GB | delete inside Photos, or turn on Optimize Mac Storage |
| Docker volumes in use | 5.2 GB | live data of running containers |
| `/Library/Developer/CommandLineTools` | 1.7 GB | git, compilers and Homebrew need it |
| `/private/var/vm` | 3.0 GB | macOS swap and sleep image |

## After cleaning

```sh
df -h /System/Volumes/Data
```

Group 1 takes you from about 7 GB to about 35 GB free; group 2 adds up to 25 GB.
Finder may show more free space than `df` because it counts purgeable space.

## How this was scanned

Read-only commands only: `scripts/scan.sh` (df, diskutil, du, find), `mo clean --dry-run`,
`mo purge --dry-run`, `docker system df`, `brew cleanup -n`, `xcrun simctl runtime list`.
`~/.Trash` was not readable (the terminal has no Full Disk Access).
