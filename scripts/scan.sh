#!/bin/bash
# Read-only disk usage scan for macOS. Prints a Markdown scan to stdout, progress to stderr.
#
# This script never deletes, moves or changes your files. It only runs: df, diskutil info, du, find
# (without -delete/-exec), ls, tmutil listlocalsnapshots, docker (df/images/ps/info), brew (list/info and
# the -n / --dry-run modes) and Mole's preview modes (mo clean --dry-run, mo purge --dry-run).
# The only file it writes is Mole's own preview list (~/.config/mole/clean-list.txt), created by Mole.
#
# Usage: bash scan.sh [--no-mole] [--fast] > scan.md
#   --no-mole  skip Mole even if it is installed
#   --fast     skip the slow whole-home searches (large files, node_modules/.venv)
#
# Works with the stock macOS /bin/bash (3.2): no associative arrays, no mapfile.

set -u

USE_MOLE=1
FAST=0
for arg in "$@"; do
  case "$arg" in
    --no-mole) USE_MOLE=0 ;;
    --fast) FAST=1 ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This scan is for macOS only." >&2
  exit 1
fi

export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_ANALYTICS=1

# Cloud folders are skipped: their sizes are misleading and walking them is slow.
DU_SKIP=(-I CloudStorage -I "Mobile Documents")
TOP=${MAC_DISK_REPORT_TOP:-20}

log() { printf '» %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# Run a command with a time limit (macOS has no `timeout`). Exit 142 means it timed out.
with_timeout() {
  local secs=$1; shift
  perl -e 'alarm shift; exec @ARGV or exit 127' "$secs" "$@"
}

strip_ansi() { sed -e $'s/\x1b\\[[0-9;?]*[a-zA-Z]//g' -e $'s/\r//g'; }

# KB -> "4.5 GB"
human() {
  awk -v k="${1:-0}" 'BEGIN { split("KB MB GB TB", u, " "); i = 1
    while (k >= 1024 && i < 4) { k /= 1024; i++ }
    printf((k < 10 && i > 1) ? "%.1f %s" : "%.0f %s", k, u[i]) }'
}

tilde() { local p=$1; printf '%s' "${p/#$HOME/~}"; }

size_kb() { du -xsk "${DU_SKIP[@]}" "$1" 2>/dev/null | awk '{print $1}'; }

# Table of the biggest children of a folder.
top_children() {
  local dir=$1 n=${2:-$TOP}
  [ -d "$dir" ] || { echo "_not present_"; echo; return; }
  echo "| Size | Path |"
  echo "| ---: | --- |"
  du -xsk "${DU_SKIP[@]}" "$dir"/* "$dir"/.[!.]* 2>/dev/null | grep -vE '/(\.DS_Store|\.localized)$' |
    sort -rn | head -n "$n" |
    while read -r kb path; do
      printf '| %s | `%s` |\n' "$(human "$kb")" "$(tilde "$path")"
    done
  echo
}

fence() { echo '```text'; cat; echo '```'; echo; }

# ---------------------------------------------------------------------------------------------

log "disk summary"
echo "# Mac disk scan (raw)"
echo
echo "- Date: $(date '+%Y-%m-%d %H:%M %Z')"
echo "- macOS: $(sw_vers -productVersion 2>/dev/null) ($(uname -m))"
echo "- Home: \`$HOME\`"
echo "- Scanner: read-only; nothing was deleted or changed"
echo

echo "## Disk"
echo
DATA_VOL=/System/Volumes/Data
[ -d "$DATA_VOL" ] || DATA_VOL=/
df -k "$DATA_VOL" | awk 'NR == 2 {
  printf "- Data volume: %.0f GB total, %.0f GB used, %.1f GB free (%s used)\n", $2/1048576, $3/1048576, $4/1048576, $5 }'
diskutil info / 2>/dev/null | awk -F: '/Container Total Space|Container Free Space/ {
  sub(/^ +/, "", $2); sub(/ \(.*/, "", $2); printf "- %s: %s\n", $1, $2 }' | sed 's/^-  */- /'
echo "- Note: Finder's \"available\" also counts purgeable space (local snapshots, iCloud cache), so it can be higher than df."
echo

log "tools"
echo "## Tools found"
echo
tools=""
for t in mo brew docker orb colima xcrun npm yarn pnpm pip3 uv poetry conda gradle pod go cargo pyenv rbenv; do
  have "$t" && tools="$tools \`$t\`"
done
[ -s "$HOME/.nvm/nvm.sh" ] && tools="$tools \`nvm\`"
echo "Installed:${tools:- none of the known tools}"
if have mo; then
  echo
  echo "Mole: $(mo --version 2>/dev/null | strip_ansi | grep -i 'version' | head -n 1)"
fi
echo

log "home folder (this is the slow part)"
echo "## Biggest folders in home"
echo
top_children "$HOME" 30

log "~/Library"
echo "## ~/Library"
echo
top_children "$HOME/Library" 12
for sub in "Application Support" Caches Containers "Group Containers" Developer; do
  echo "### ~/Library/$sub"
  echo
  top_children "$HOME/Library/$sub" 15
done

log "system locations"
echo "## System locations"
echo
echo "### /Applications"
echo
top_children /Applications 20
BREW_PREFIX=""
have brew && BREW_PREFIX=$(brew --prefix 2>/dev/null)
echo "### Other system folders"
echo
echo "| Size | Path | What |"
echo "| ---: | --- | --- |"
while IFS='|' read -r path what; do
  [ -e "$path" ] || continue
  printf '| %s | `%s` | %s |\n' "$(human "$(size_kb "$path")")" "$path" "$what"
done <<EOF
${BREW_PREFIX:-/opt/homebrew}|Homebrew prefix
/Library/Developer/CommandLineTools|Xcode Command Line Tools (git, clang): keep
/Library/Developer/CoreSimulator|iOS simulator runtimes (system-wide)
/Applications/Xcode.app|Xcode
/private/var/vm|swap and sleep image, managed by macOS: keep
/Library/Caches|system-wide caches
/Users/Shared|shared files
EOF
echo

log "known developer and app locations"
echo "## Known locations"
echo
echo "Sizes of folders that are often large. Look each up in references/cleanup-catalog.md."
echo
echo "| Size | Path | What |"
echo "| ---: | --- | --- |"
BREW_CACHE=$(have brew && brew --cache 2>/dev/null)
while IFS='|' read -r path what; do
  path=${path/#\~/$HOME}
  [ -e "$path" ] || continue
  kb=$(size_kb "$path")
  [ "${kb:-0}" -ge 10240 ] || continue   # skip anything under 10 MB
  printf '%s\t| %s | `%s` | %s |\n' "$kb" "$(human "$kb")" "$(tilde "$path")" "$what"
done <<EOF | sort -rn | cut -f2-
~/Library/Developer/Xcode/DerivedData|Xcode build products
~/Library/Developer/Xcode/Archives|Xcode archives (app builds you shipped)
~/Library/Developer/Xcode/iOS DeviceSupport|iOS device debug symbols
~/Library/Developer/Xcode/watchOS DeviceSupport|watchOS device debug symbols
~/Library/Developer/CoreSimulator|iOS simulator devices
~/Library/Caches/com.apple.dt.Xcode|Xcode cache
~/Library/Android/sdk|Android SDK
~/.android/avd|Android emulator images
~/.gradle/caches|Gradle cache
~/.gradle/wrapper|Gradle wrapper downloads
~/.m2/repository|Maven repository
~/.npm|npm cache
~/Library/Caches/Yarn|Yarn cache
~/.yarn/berry/cache|Yarn Berry cache
~/Library/pnpm/store|pnpm store
~/Library/Caches/pip|pip cache
~/.cache/pip|pip cache
~/.cache/uv|uv cache
~/Library/Caches/pypoetry/cache|Poetry cache
~/Library/Caches/pypoetry/artifacts|Poetry downloads
~/Library/Caches/pypoetry/virtualenvs|Poetry project virtualenvs
~/.cache/pre-commit|pre-commit hook envs
~/.cache/huggingface|Hugging Face models and datasets
~/.ollama/models|Ollama models
~/.conda/pkgs|conda package cache
~/anaconda3|Anaconda install
~/miniconda3|Miniconda install
~/opt/anaconda3|Anaconda install
~/go/pkg/mod|Go module cache
~/Library/Caches/go-build|Go build cache
~/.cargo/registry|Cargo registry
~/.rustup/toolchains|Rust toolchains
~/Library/Caches/CocoaPods|CocoaPods cache
~/.cocoapods|CocoaPods specs
~/.nvm/versions/node|nvm Node versions
~/.fnm|fnm Node versions
~/.volta|Volta toolchains
~/.pyenv/versions|pyenv Python versions
~/.rbenv/versions|rbenv Ruby versions
~/Library/Caches/ms-playwright|Playwright browsers
${BREW_CACHE:-~/Library/Caches/Homebrew}|Homebrew download cache (brew --cache)
~/Library/Containers/com.docker.docker|Docker Desktop disk image
~/.docker|Docker CLI data
~/.orbstack|OrbStack data
~/.colima|Colima VMs
~/.lima|Lima VMs
~/Library/Containers/com.utmapp.UTM|UTM virtual machines
~/Parallels|Parallels virtual machines
~/Library/Application Support/Claude/vm_bundles|Claude desktop VM image
~/Library/Application Support/MobileSync/Backup|iPhone/iPad backups
~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads|Mail attachment downloads
~/Library/Messages/Attachments|Messages attachments
~/Library/Caches/com.microsoft.VSCode.ShipIt|VS Code updater leftovers
~/Library/Application Support/Code/CachedExtensionVSIXs|VS Code extension downloads
~/Library/Application Support/Code/User/workspaceStorage|VS Code per-workspace data
~/Library/Application Support/Cursor/User/workspaceStorage|Cursor per-workspace data
~/Library/Application Support/Local|Local (WordPress) sites
~/Library/Logs|app logs
~/Downloads|Downloads
~/.Trash|Trash
EOF
echo

log "runtime versions"
echo "## Language runtime versions"
echo
for d in "$HOME/.nvm/versions/node" "$HOME/.pyenv/versions" "$HOME/.rbenv/versions" "$HOME/.rustup/toolchains"; do
  [ -d "$d" ] || continue
  echo "### $(tilde "$d")"
  echo
  top_children "$d" 30
done
[ -f "$HOME/.nvm/alias/default" ] && echo "- nvm default: \`$(cat "$HOME/.nvm/alias/default")\`"
have pyenv && echo "- pyenv global: \`$(pyenv global 2>/dev/null | tr '\n' ' ')\`"
echo

log "docker"
echo "## Docker"
echo
if have docker; then
  echo "Contexts (\`*\` = active):"
  echo
  with_timeout 15 docker context ls 2>&1 | fence
  if with_timeout 20 docker info --format '{{.ServerVersion}}' >/dev/null 2>&1; then
    with_timeout 60 docker system df 2>&1 | fence
    echo "### Images"
    echo
    with_timeout 60 docker images --format '{{.Size}}\t{{.Repository}}:{{.Tag}}\t{{.CreatedSince}}' 2>&1 | head -n 40 | fence
    echo "- Dangling (untagged) images: $(with_timeout 30 docker images -f dangling=true -q 2>/dev/null | wc -l | tr -d ' ')"
    echo
    echo "### Volumes (LINKS 0 = no container uses it)"
    echo
    with_timeout 120 docker system df -v 2>/dev/null |
      awk '/^Local Volumes space usage/ {on = 1; next} /^Build cache usage/ {on = 0} on && NF' | fence
    echo "### Stopped containers"
    echo
    with_timeout 60 docker ps -a -s -f status=exited -f status=created --format '{{.Names}}\t{{.Image}}\t{{.Size}}\t{{.Status}}' 2>&1 | fence
  else
    echo "_The Docker CLI is installed but no daemon answered. Start Docker Desktop (or OrbStack/Colima) and rerun for image and volume details._"
    echo
  fi
  RAW="$HOME/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw"
  if [ -f "$RAW" ]; then
    echo "- Docker Desktop disk image \`$(tilde "$RAW")\`: $(human "$(size_kb "$RAW")") on disk (sparse file; its maximum is $(ls -lh "$RAW" | awk '{print $5}'))"
    echo
  fi
else
  echo "_Docker not installed._"
  echo
fi

log "homebrew"
echo "## Homebrew"
echo
if have brew; then
  echo "### Cellar (formulae)"
  echo
  top_children "$BREW_PREFIX/Cellar" 15
  echo "### Caskroom (apps and their installers)"
  echo
  top_children "$BREW_PREFIX/Caskroom" 15
  echo "### brew cleanup -n (preview)"
  echo
  # Drop the per-formula "Skipping" warnings; autoremove has its own section below.
  out=$(with_timeout 180 brew cleanup -n 2>&1 | grep -v '^Warning: Skipping' | sed '/Would autoremove/,$d' | tail -n 25)
  if [ -n "$out" ]; then printf '%s\n' "$out" | fence; else echo "_nothing to clean_"; echo; fi
  echo "### brew autoremove --dry-run (formulae only installed as dependencies)"
  echo
  with_timeout 120 brew autoremove --dry-run 2>&1 | tail -n 30 | fence
  if have python3; then
    echo "### Casks whose app is missing"
    echo
    with_timeout 120 brew info --cask --installed --json=v2 2>/dev/null | python3 -I -c '
import json, os, sys
try:
    casks = json.load(sys.stdin)["casks"]
except Exception:
    sys.exit(0)
home = os.path.expanduser("~")
missing = []
for c in casks:
    for art in c.get("artifacts") or []:
        if not (isinstance(art, dict) and "app" in art):
            continue
        for entry in art["app"]:
            name = entry if isinstance(entry, str) else (entry[0] if isinstance(entry, list) and entry else None)
            if isinstance(entry, dict):
                name = entry.get("target")
            if not isinstance(name, str):
                continue
            name = os.path.basename(name)
            if not any(os.path.exists(os.path.join(d, name)) for d in ("/Applications", home + "/Applications")):
                missing.append((c["token"], name))
if missing:
    for token, app in missing:
        print(f"- `{token}`: `{app}` is not in /Applications")
else:
    print("_none_")
'
    echo
  fi
else
  echo "_Homebrew not installed._"
  echo
fi

if [ "$USE_MOLE" = 1 ] && have mo; then
  log "mole clean --dry-run (can take a few minutes)"
  echo "## Mole: mo clean --dry-run"
  echo
  with_timeout 600 mo clean --dry-run </dev/null 2>&1 | strip_ansi | grep -v '^[[:space:]]*$' | tail -n 150 | fence
  log "mole purge --dry-run"
  echo "## Mole: mo purge --dry-run"
  echo
  with_timeout 300 mo purge --dry-run </dev/null 2>&1 | strip_ansi | grep -v '^[[:space:]]*$' | tail -n 60 | fence
else
  echo "## Mole"
  echo
  if have mo; then
    echo "_Skipped (--no-mole)._"
  else
    echo "_Mole is not installed. \`brew install mole\` adds app-cache and leftover-file checks to this scan._"
  fi
  echo
fi

log "time machine local snapshots"
echo "## Time Machine local snapshots"
echo
with_timeout 30 tmutil listlocalsnapshots / 2>&1 | fence

log "old installers"
echo "## Installer files (.dmg .pkg .iso .xip over 10 MB)"
echo
found=$(find "$HOME/Downloads" "$HOME/Desktop" "$HOME/Documents" -maxdepth 3 -type f \
  \( -iname '*.dmg' -o -iname '*.pkg' -o -iname '*.iso' -o -iname '*.xip' \) -size +20480 2>/dev/null)
if [ -n "$found" ]; then
  echo "| Size | Path |"
  echo "| ---: | --- |"
  printf '%s\n' "$found" | while read -r f; do
    printf '%s\t| %s | `%s` |\n' "$(size_kb "$f")" "$(human "$(size_kb "$f")")" "$(tilde "$f")"
  done | sort -rn | cut -f2-
else
  echo "_none_"
fi
echo

if [ "$FAST" = 0 ]; then
  log "files over 1 GB in home (up to 5 minutes)"
  echo "## Files over 1 GB in home"
  echo
  big=$(with_timeout 300 find -x "$HOME" \( -path "$HOME/Library/CloudStorage" -o -path "$HOME/Library/Mobile Documents" \) -prune \
    -o -type f -size +2097152 -print 2>/dev/null)
  if [ -n "$big" ]; then
    echo "| Size | Path |"
    echo "| ---: | --- |"
    printf '%s\n' "$big" | while read -r f; do
      printf '%s\t| %s | `%s` |\n' "$(size_kb "$f")" "$(human "$(size_kb "$f")")" "$(tilde "$f")"
    done | sort -rn | cut -f2- | head -n 30
  else
    echo "_none found (or the search timed out)_"
  fi
  echo

  log "node_modules and .venv folders (up to 5 minutes)"
  echo "## Project dependency folders (node_modules, .venv) over 50 MB"
  echo
  deps=$(with_timeout 300 find -x "$HOME" -maxdepth 7 \
    \( -path "$HOME/Library" -o -path "$HOME/.Trash" -o -path "$HOME/.nvm" -o -path "$HOME/.npm" -o -path "$HOME/.cache" \) -prune \
    -o -type d \( -name node_modules -o -name .venv \) -print -prune 2>/dev/null)
  if [ -n "$deps" ]; then
    echo "| Size | Path | Last changed |"
    echo "| ---: | --- | --- |"
    printf '%s\n' "$deps" | while read -r d; do
      kb=$(size_kb "$d")
      [ "${kb:-0}" -ge 51200 ] || continue
      printf '%s\t| %s | `%s` | %s |\n' "$kb" "$(human "$kb")" "$(tilde "$d")" "$(stat -f '%Sm' -t '%Y-%m-%d' "$(dirname "$d")" 2>/dev/null)"
    done | sort -rn | cut -f2- | head -n 30
  else
    echo "_none found_"
  fi
  echo
fi

echo "## Not readable"
echo
echo "Folders macOS protects (Mail, Messages, Safari, Trash, some app containers) show up small or missing"
echo "unless the terminal app has Full Disk Access (System Settings > Privacy & Security > Full Disk Access)."
if ! ls "$HOME/.Trash" >/dev/null 2>&1; then
  echo
  echo "- \`~/.Trash\` was not readable in this run."
fi
echo

log "done"
