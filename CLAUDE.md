# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal Arch Linux configuration sync tool. It reads plain-text package lists and a mirrorlist, then idempotently applies them to the local system. It must be run as a non-root user (it calls `sudo` internally when needed).

`arch-sync.sh` at the repo root is a thin orchestrator: it sources `scripts/common.sh` and then runs each step script under `scripts/` in order (as subprocesses). Each step is a standalone, independently runnable script — e.g. `./scripts/sort-package-lists.sh` re-sorts the lists without touching anything else.

## Running the script

```bash
./arch-sync.sh
```

To run a single step on its own:

```bash
./scripts/<step>.sh   # e.g. ./scripts/install-packages.sh
```

Prerequisites: `git`, `yay` (AUR helper). The script will error early if `yay` is missing and AUR packages are listed.

## Script layout

- `arch-sync.sh` — orchestrator at the repo root; runs the step scripts in order.
- `scripts/common.sh` — sourced library shared by every step: config-path variables, color/log helpers (`log_info` etc.), the entry parsers `parse_entry()` and `entry_name()`, and the non-root guard. Sourced, never executed directly.
- `scripts/<step>.sh` — one script per step (see execution order below). Each sources `common.sh`, defines its function(s), and calls the function. Step-private helpers live with their step: `dedupe_internal`/`dedupe_install_against_remove` in `dedupe-package-lists.sh`, `sort_list_file` in `sort-package-lists.sh`.

## Configuration files

All configuration files live in the `config/` directory. Each tracked config file ships with a `<name>.example` sibling (e.g. `packages-install.txt.example`) that serves as a starter template — the real files are user-edited and not meant to be portable across machines.

| File | Purpose |
|---|---|
| `config/packages-install.txt` | Official repo packages installed via `pacman` |
| `config/packages-aur-install.txt` | AUR packages installed via `yay` |
| `config/packages-remove.txt` | Packages to uninstall (checked with `pacman -Qi`, removed with `yay -Rns`) |
| `config/directories-remove.txt` | Paths/directories to delete (prompts for confirmation; supports `~` expansion) |
| `config/home-directories.txt` | Directory paths relative to `$HOME` to symlink into `~/Cloud_Storage/Dropbox` |
| `config/home-files.txt` | File paths relative to `$HOME` to symlink into `~/Cloud_Storage/Dropbox` (copies existing file into sync target before linking) |
| `config/mirrorlist` | Copied verbatim to `/etc/pacman.d/mirrorlist` |
| `config/pacman.conf` | Copied verbatim to `/etc/pacman.conf` |

All list files support `#` comments and blank lines. One entry per line. Entries can be scoped to specific hostnames using `@hostname` tags (see below).

## Script execution order

`arch-sync.sh` runs these step scripts in this order:

1. `update-databases.sh` — `yay -Sy` refreshes package databases
2. `sync-mirrors.sh` — copy `mirrorlist` → `/etc/pacman.d/mirrorlist`
3. `sync-pacman-conf.sh` — copy `pacman.conf` → `/etc/pacman.conf`
4. `dedupe-package-lists.sh` — deduplicate the package list files (see Deduplication below) — runs before removal/installation so the rest of the run acts on the cleaned lists
5. `remove-packages.sh` — remove listed packages (skips already-absent packages with a warning, does not abort)
6. `remove-directories.sh` — remove listed directories (interactive confirmation)
7. `link-home-directories.sh` — link home directories to `~/Cloud_Storage/Dropbox` (creates symlinks; renames existing dirs to `<dir>_old`)
8. `link-home-files.sh` — link home files to `~/Cloud_Storage/Dropbox` (copies existing file into sync target if missing, then renames original to `<file>_old` and creates symlink)
9. `install-packages.sh` — install official packages (skips already-installed)
10. `install-aur-packages.sh` — install AUR packages (skips already-installed)
11. `sort-package-lists.sh` — sort the package list files alphabetically (`packages-install.txt`, `packages-aur-install.txt`, `packages-remove.txt`) — leading comment header is preserved; inline comments and `@hostname` tags stay attached to their entry; blank lines within the body are dropped

## Hostname-based filtering

Each list file supports `@hostname` tags to restrict an entry to specific machines. The script captures `$HOSTNAME` at startup and runs each line through `parse_entry()`, which strips inline comments, collects `@tag` words, and compares them against the current host.

- No tags → applies to all hosts
- One or more tags → only applied on matching hosts
- Paths with embedded spaces are not supported when using `@hostname` tags

Examples:

```
postgresql      @armini          # install only on armini
postgresql      @arbook @arpad   # remove on arbook and arpad, but not armini
ydotool                          # install on all machines
```

## Deduplication

Before acting on the lists, the script deduplicates package names in `packages-install.txt`, `packages-aur-install.txt`, and `packages-remove.txt` via `dedupe_package_lists()`. Parsing reuses `entry_name()`, a host-agnostic variant of `parse_entry()`.

- **Within-file**: exact duplicate package names in the same file are collapsed to the first occurrence (its inline comment is kept).
- **Cross-file**: a name present in an install file *and* the remove list is dropped from the install file and kept only in the remove list.
- **Hostname tags are skipped**: any entry carrying an `@hostname` tag is left untouched by both rules. This preserves intentional splits such as `postgresql @armini` (install) vs `postgresql @arbook @arpad` (remove).

Dropped entries are reported with `[WARN]`. Comments and blank lines are preserved.

## Key behaviors

- `set -e` is active in every step script and in the orchestrator. Because the orchestrator runs steps as subprocesses, a step exiting non-zero aborts the whole run (matching the previous single-script behavior).
- Package removal failures are logged as warnings and skipped rather than aborting (changed from earlier behavior that used `set -e` on removal).
- A remove-list entry that resolves through another package's `Provides` (rather than being a real installed package) will pass the `pacman -Qi` guard but then fail `yay -Rns` with `error: target not found` and exit status 1. This surfaces as a `[WARN] Failed to remove ...` line; the script continues. This is **intentional** — the visible error is a flag to investigate the entry, not a bug. Do not "fix" the guard to match exact installed names (e.g. `grep -Fxq` against `pacman -Qq`), as that would silently drop the entry and suppress the signal. Example: `pandoc-cli` is provided by `pandoc-bin`, so listing `pandoc-cli` for removal warns every run unless the line is deleted.
