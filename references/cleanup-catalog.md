# Cleanup catalog

What common space users on a Mac are, which group they belong to, and the command to put in the report.
These commands are for the **report only**: the person runs them, the agent never does.
When copying them into a report, follow SKILL.md's "Paste-safe in anyone's terminal" rules (no `#`
comments in command blocks, `$HOME` inside quotes, `"$(brew --prefix)"` instead of a Homebrew path).

Groups: **Safe** (rebuilds itself), **Check first** (may hold work or data), **Leave alone**.

## Contents

- [Docker and other VMs](#docker-and-other-vms)
- [Xcode and iOS simulators](#xcode-and-ios-simulators)
- [Android](#android)
- [JavaScript](#javascript)
- [Python](#python)
- [Other languages](#other-languages)
- [Homebrew](#homebrew)
- [Apps and editors](#apps-and-editors)
- [Mole](#mole)
- [Personal files](#personal-files)
- [Leave alone](#leave-alone)

## Docker and other VMs

Docker Desktop keeps everything in one disk image,
`~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw`. It is a sparse file: after pruning,
its on-disk size usually drops on its own; if not, restart Docker Desktop. Don't delete `Docker.raw` by
hand: that erases every image, container and volume at once.

| Item | Group | Check | Clean | What you lose |
| --- | --- | --- | --- | --- |
| Build cache | Safe | `docker system df` | `docker builder prune -f` | slower next build |
| Dangling images | Safe | `docker images -f dangling=true` | `docker image prune -f` | nothing |
| Unused images | Check first | `docker images` | `docker image prune -a -f` | every image no container uses, including ones you can't get back: made with `docker commit`, built locally from a Dockerfile that is gone, or pulled tags since removed upstream. Otherwise re-pull/rebuild later |
| Stopped containers | Check first | `docker ps -a -f status=exited` | `docker container prune -f` | their changes and logs |
| Unused volumes | Check first | `docker volume ls -f dangling=true` | `docker volume rm <name>` | **the data in them** (databases) |
| Docker Desktop disk limit | Check first | Settings > Resources > Disk usage limit | lower the limit in Settings | the app may need to reset the image |

Never suggest `docker system prune --volumes` as one line: it mixes safe and data-losing steps.
`docker` commands need the daemon running; quit nothing.

Other VM tools:

| Item | Group | Clean |
| --- | --- | --- |
| OrbStack (`~/.orbstack`, `~/OrbStack`) | Check first | delete machines/images in the app; uninstall: `brew uninstall --cask --zap orbstack`, then `docker context rm orbstack` |
| Colima (`~/.colima`) | Check first | `colima list`, then `colima delete <profile>` |
| Lima (`~/.lima`) | Check first | `limactl list`, then `limactl delete <name>` |
| UTM, Parallels, VMware | Check first | delete VMs inside the app |
| Two Docker engines installed | Check first | keep the one in use (`docker context show`), uninstall the other |
| Claude desktop VM (`~/Library/Application Support/Claude/vm_bundles`) | Leave alone | used by the Claude desktop app's VM features; the app downloads it again if removed. Only goes away by uninstalling the app |

## Xcode and iOS simulators

Quit Xcode and Simulator first.

| Item | Group | Check | Clean | What you lose |
| --- | --- | --- | --- | --- |
| DerivedData | Safe | `du -sh ~/Library/Developer/Xcode/DerivedData` | `rm -rf ~/Library/Developer/Xcode/DerivedData` | slower next build |
| Xcode caches | Safe | `du -sh ~/Library/Caches/com.apple.dt.Xcode` | `rm -rf ~/Library/Caches/com.apple.dt.Xcode` | nothing |
| iOS/watchOS DeviceSupport | Safe | `ls ~/Library/Developer/Xcode/iOS\ DeviceSupport` | `rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/<old version>` | re-copied when that device connects |
| Unavailable simulators | Safe | `xcrun simctl list devices unavailable` | `xcrun simctl delete unavailable` | nothing |
| Simulator devices | Check first | `xcrun simctl list devices` | `xcrun simctl erase all` (resets) or `xcrun simctl delete <udid>` | apps and data in those simulators |
| Simulator runtimes | Check first | `xcrun simctl runtime list` | `xcrun simctl runtime delete <id>` | re-download in Xcode > Settings > Components |
| Archives | Check first | `ls ~/Library/Developer/Xcode/Archives` | delete old ones in Xcode > Organizer | dSYMs for crash reports of shipped builds |

**Xcode no longer installed** (no `xcrun simctl`, but `CoreSimulator` folders remain): the data is left
over. Check first, then:

```sh
rm -rf ~/Library/Developer/CoreSimulator
sudo rm -rf /Library/Developer/CoreSimulator
```

The second line removes the system-wide runtimes and asks for your password.

If the `sudo` line says "Resource busy", restart the Mac and run it again. Keep
`/Library/Developer/CommandLineTools`: git, Homebrew and compilers need it.

## Android

Quit Android Studio and stop Gradle first (`gradle --stop` or `pkill -f GradleDaemon`).

| Item | Group | Check | Clean | What you lose |
| --- | --- | --- | --- | --- |
| Gradle caches | Safe | `du -sh ~/.gradle/caches` | `rm -rf ~/.gradle/caches` | re-download on next build |
| Gradle wrapper dists | Safe | `ls ~/.gradle/wrapper/dists` | `rm -rf ~/.gradle/wrapper/dists` | re-download per project |
| Emulator images (AVDs) | Check first | `ls ~/.android/avd` | Android Studio > Device Manager > Delete, or `rm -rf ~/.android/avd/<name>.avd ~/.android/avd/<name>.ini` | that emulator and its data |
| SDK system images | Check first | `du -sh ~/Library/Android/sdk/system-images/*` | Android Studio > SDK Manager, uncheck | re-download |
| No Android work any more | Check first | | `rm -rf ~/.android ~/.gradle` (and `~/Library/Android` if Android Studio is gone) | all of the above plus adb keys |

## JavaScript

| Item | Group | Check | Clean |
| --- | --- | --- | --- |
| npm cache | Safe | `du -sh ~/.npm` | `npm cache clean --force` |
| Yarn (classic) cache | Safe | `yarn cache dir` | `yarn cache clean` |
| Yarn Berry cache | Safe | `du -sh ~/.yarn/berry/cache` | `rm -rf ~/.yarn/berry/cache` |
| pnpm store | Safe | `pnpm store path` | `pnpm store prune` |
| Playwright browsers | Safe | `du -sh ~/Library/Caches/ms-playwright` | `rm -rf ~/Library/Caches/ms-playwright` (reinstall: `npx playwright install`) |
| Old Node versions (nvm) | Check first | `nvm ls` | `nvm uninstall <version>`; keep the default (`nvm alias default`) |
| Old Node versions (fnm / Volta) | Check first | `fnm list` / `volta list all` | `fnm uninstall <version>` / remove in Volta |
| Bun cache | Safe | `du -sh ~/.bun/install/cache` | `bun pm cache rm` |
| node-gyp headers | Safe | `du -sh ~/Library/Caches/node-gyp` | `rm -rf ~/Library/Caches/node-gyp` (re-downloaded on the next native build) |
| Puppeteer browsers | Safe | `du -sh ~/.cache/puppeteer` | `rm -rf ~/.cache/puppeteer` (reinstall: `npx puppeteer browsers install chrome`) |
| Cypress app binaries | Safe | `du -sh ~/Library/Caches/Cypress` | `rm -rf ~/Library/Caches/Cypress` (reinstall: `npx cypress install`) |
| `node_modules` in old projects | Check first | the scan's table (last changed date) | `rm -rf "<project>/node_modules"`; `npm install` restores it |

`nvm` is a shell function, not a program: in a fresh terminal run `. "${NVM_DIR:-$HOME/.nvm}/nvm.sh"`
first, or `nvm` is "command not found".

## Python

| Item | Group | Check | Clean |
| --- | --- | --- | --- |
| pip cache | Safe | `pip3 cache dir` | `pip3 cache purge` |
| uv cache | Safe | `uv cache dir` | `uv cache clean` (or `uv cache prune` to keep what projects use) |
| Poetry cache and downloads | Safe | `du -sh ~/Library/Caches/pypoetry/*` | `rm -rf ~/Library/Caches/pypoetry/cache ~/Library/Caches/pypoetry/artifacts` |
| Poetry virtualenvs | Check first | `ls ~/Library/Caches/pypoetry/virtualenvs` | `rm -rf ~/Library/Caches/pypoetry/virtualenvs/<env>`; `poetry install` recreates |
| pre-commit envs | Safe | `du -sh ~/.cache/pre-commit` | `pre-commit clean` |
| conda package cache | Safe | `conda info` | `conda clean --all -y` |
| Hugging Face cache | Check first | `hf cache ls` | `hf cache rm <repo id>` per model (asks to confirm); `hf cache prune` removes only unreferenced revisions and broken downloads. An older install has only `huggingface-cli scan-cache` / `huggingface-cli delete-cache` (interactive) |
| Ollama models | Check first | `ollama list` | `ollama rm <model>` |
| Old Python versions (pyenv) | Check first | `pyenv versions` | `pyenv uninstall <version>`; keep `pyenv global` |
| Anaconda install not used | Check first | | `brew uninstall --cask anaconda` or remove `~/anaconda3` |
| `.venv` in old projects | Check first | the scan's table | `rm -rf "<project>/.venv"`; recreate with `uv sync` / `python -m venv` |

## Other languages

| Item | Group | Check | Clean |
| --- | --- | --- | --- |
| Go build cache | Safe | `go env GOCACHE` | `go clean -cache` |
| Go module cache | Safe | `du -sh ~/go/pkg/mod` | `go clean -modcache` |
| Cargo registry cache | Safe | `du -sh ~/.cargo/registry` | `rm -rf ~/.cargo/registry/cache` |
| Rust `target/` in old projects | Safe | the scan's dependency table | `cargo clean --manifest-path "<project>/Cargo.toml"`; the next build is slow |
| Rust toolchains | Check first | `rustup toolchain list` | `rustup toolchain uninstall <name>` |
| Dart/Flutter pub cache | Safe | `du -sh ~/.pub-cache` | `dart pub cache clean` (asks to confirm); `flutter pub get` restores packages |
| Maven repository | Check first | `du -sh ~/.m2/repository` | `rm -rf ~/.m2/repository`; downloads come back, but artifacts you built with `mvn install` exist nowhere else |
| CocoaPods cache | Safe | `du -sh ~/Library/Caches/CocoaPods` | `pod cache clean --all` |
| Ruby versions (rbenv) | Check first | `rbenv versions` | `rbenv uninstall <version>` |

## Homebrew

| Item | Group | Check | Clean |
| --- | --- | --- | --- |
| Old versions and downloads | Safe | `brew cleanup -n` | `brew cleanup --prune=all` |
| Unneeded dependencies | Check first | `brew autoremove --dry-run` | `brew autoremove`. Check the list: a "dependency" like `go` or `ruby` may be one you use directly; keep it with `brew install <name>` first (marks it as wanted) |
| Formulae you no longer use | Check first | `brew leaves` | `brew uninstall <name>` |
| Cask whose app is gone | Check first | scan's "Casks whose app is missing" | `brew uninstall --cask --zap <token>` (`--zap` also removes the app's support files) |

## Apps and editors

Quit the app before clearing its cache.

| Item | Group | Clean |
| --- | --- | --- |
| VS Code updater leftovers (`~/Library/Caches/com.microsoft.VSCode.ShipIt`) | Safe | `rm -rf ~/Library/Caches/com.microsoft.VSCode.ShipIt` |
| VS Code extension downloads (`CachedExtensionVSIXs`) | Safe | `rm -rf ~/Library/Application\ Support/Code/CachedExtensionVSIXs` |
| VS Code / Cursor `workspaceStorage` | Check first | per-workspace state (undo history, extension data) for old projects; delete old subfolders only |
| VS Code extensions (`~/.vscode/extensions`) | Check first | `code --list-extensions --show-versions`; uninstall unused ones in the Extensions view. Folders of replaced versions go after a VS Code restart; don't delete extension folders by hand |
| JetBrains caches (`~/Library/Caches/JetBrains`) | Safe | `ls ~/Library/Caches/JetBrains`, then `rm -rf ~/Library/Caches/JetBrains/<old IDE version>` for versions you no longer run; the current one re-indexes if removed |
| Slack cache | Safe | quit Slack, then `rm -rf "$HOME/Library/Application Support/Slack/Cache" "$HOME/Library/Application Support/Slack/Service Worker/CacheStorage"` (App Store Slack: the same folders under `~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack`) |
| One app's cache in `~/Library/Caches/<bundle id>` | Safe | `rm -rf ~/Library/Caches/<bundle id>` |
| App you uninstalled, data left in `~/Library/Application Support/<App>` or `~/Library/Containers/<id>` | Check first | confirm the app is gone, then remove that folder |
| App you want to uninstall | Check first | `mo uninstall` (removes the app and its leftovers) or drag to Trash |
| Local (WordPress) sites (`~/Library/Application Support/Local`) | Check first | delete sites inside Local; if Local is gone, remove the folder |
| Logs (`~/Library/Logs`) | Safe | `rm -rf ~/Library/Logs/<app>` for big ones |
| Dotfolder of a tool you no longer use (`~/.<tool>`) | Check first | `rm -rf ~/.<tool>` after confirming the tool is gone |

Never clear all of `~/Library/Caches` or `~/Library/Application Support` in one command.

## Mole

If Mole is installed, its dry run lists caches, logs and leftovers it considers safe; it also flags
orphan dotfiles, stale login items and project artifacts for review.

| Item | Group | Clean |
| --- | --- | --- |
| Everything `mo clean --dry-run` listed | Safe | `mo clean` (full list of what it removes: `~/.config/mole/clean-list.txt`; protect items with `mo clean --whitelist`) |
| Project artifacts | Check first | `mo purge` (lets you pick) |
| Old installers | Check first | `mo installer` (lets you pick) |
| Unwanted apps | Check first | `mo uninstall` |

## Personal files

| Item | Group | Clean |
| --- | --- | --- |
| Trash | Check first | Finder > Empty Trash |
| Downloads, old installers (`.dmg`, `.pkg`, `.iso`) | Check first | review in Finder, move to Trash |
| Files over 1 GB | Check first | review each; move to an external drive or Trash |
| iPhone/iPad backups | Check first | Finder > device > Manage Backups (not `rm`) |
| Mail / Messages attachments | Check first | System Settings > General > Storage > Messages / Mail |
| Time Machine local snapshots | Leave alone usually | macOS deletes them when space runs low; to remove now: `tmutil listlocalsnapshots /`, then `tmutil deletelocalsnapshots <date>` |

## Leave alone

| Path | Why |
| --- | --- |
| `/System`, `/private/var/vm` | macOS swap and sleep image; managed by the system |
| `/Library/Developer/CommandLineTools` | git, clang, Homebrew builds need it |
| `~/Library/Mobile Documents`, `~/Library/CloudStorage` | iCloud Drive and cloud drives; manage in their apps |
| Photos Library | delete inside Photos, or use "Optimize Mac Storage" |
| Keychains, `~/.ssh`, browser profiles | credentials |
| Docker volumes in use (LINKS > 0) | live data of running projects |
| `Docker.raw` | shrink through Docker, never by deleting the file |
| "System Data" in Storage settings | a label for many things above; clean the parts, not the label |
