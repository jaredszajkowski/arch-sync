# arch-sync

This is a template repository for syncing packages and configurations across multiple Arch Linux installations. It includes a script to automate the installation and removal of packages and the synchronization of configuration files.

## Requirements

There is a short list of requirements for using this repository:

* Arch Linux installed on your machines.
* `git` installed to clone the repository and pull/push changes.
* `yay` installed for managing AUR (Arch User Repository) packages.

I personally use `yay` for *most* of my AUR package management, but you can modify the script to use your preferred AUR helper if needed.

## Installation

You can use this repository as a starting point for your own Arch Linux setup. Simply clone the repository, customize the package lists and configuration files to your liking, and run the `arch-sync.sh` script to apply the changes to your system.

## Usage

1. Fork the repository to your own GitHub account.

2. Clone the repository:

```bash
$ git clone https://github.com/username/arch-sync.git
```

3. Copy the example files in `config/` to create your own configuration, then edit them to include the packages and configurations you want to manage:

```bash
$ cd arch-sync/config
$ for f in *.example; do cp "$f" "${f%.example}"; done
```

The files to edit are `packages-install.txt`, `packages-aur-install.txt`, `packages-remove.txt`, `directories-remove.txt`, `home-directories.txt`, `home-files.txt`, `mirrorlist`, and `pacman.conf` — all located in `config/`.

4. Run the synchronization script:

```bash
$ cd arch-sync
$ chmod +x arch-sync.sh
$ ./arch-sync.sh
```

The script will read the package lists and configuration files, install or remove packages as needed, and synchronize your configuration. If the package lists or configuration files have changed since the last run, it will apply the necessary changes to your system. If there are no changes or the changes have already been applied, it will simply exit without making any modifications.

5. Commit and push your changes to your forked repository:

```bash
$ git add .
$ git commit -m "Update package lists and configurations"
$ git push
```

## Configuration Files

All configuration files live in the `config/` directory. Each file has a corresponding `*.example` template to use as a starting point.

* `config/packages-install.txt`: A list of packages to be installed using `pacman`.
* `config/packages-aur-install.txt`: A list of AUR packages to be installed using `yay`.
* `config/packages-remove.txt`: A list of packages to be removed.
* `config/directories-remove.txt`: A list of directories and files to be removed.
* `config/home-directories.txt`: A list of home directory paths (relative to `$HOME`) to symlink into `~/Cloud_Storage/Dropbox`.
* `config/home-files.txt`: A list of home file paths (relative to `$HOME`) to symlink into `~/Cloud_Storage/Dropbox`.
* `config/mirrorlist`: Custom mirrorlist for pacman, copied verbatim to `/etc/pacman.d/mirrorlist`.
* `config/pacman.conf`: Custom pacman configuration, copied verbatim to `/etc/pacman.conf`.

Each of these files can be edited to include the packages (1 package per line) and Arch Linux configuration files you want to manage across your machines.

## Home Directory and File Linking

The `home-directories.txt` and `home-files.txt` files list paths relative to `$HOME` that should be symlinked into `~/Cloud_Storage/Dropbox`. This keeps important directories and dotfiles synced across machines via Dropbox (or any other sync folder).

**How it works:**

- Each line is a path relative to `$HOME` (no leading `~/`).
- Use `home-directories.txt` for directories and `home-files.txt` for individual files.
- If the target already exists, it is renamed to `<entry>_old` before the symlink is created. For files, the original content is first copied to the sync folder if it isn't already present there.
- If the target is already a symlink, it is left as-is.
- If `<entry>_old` already exists, the entry is skipped with a warning.
- Parent directories within the sync folder are created automatically.
- Supports `@hostname` tags to scope entries to specific machines.

**Examples (`home-directories.txt`):**

```
# Link ~/.claude on all machines
.claude

# Link ~/Documents only on arbook
Documents    @arbook

# Link ~/.config/some-app on arbook and arpad
.config/some-app    @arbook @arpad
```

**Examples (`home-files.txt`):**

```
# Link ~/.claude.json on all machines
.claude.json

# Link ~/.gitconfig only on arbook
.gitconfig    @arbook
```

## Hostname-Based Filtering

All configuration files support optional `@hostname` tags to restrict an entry to specific machines. This allows you to maintain a single set of config files that behaves differently depending on which host the script is running on.

**How it works:**

- Entries with **no** `@hostname` tags apply to **all** hosts.
- Entries with **one or more** `@hostname` tags apply **only** to hosts whose name matches one of the tags.
- Tags can be placed anywhere on the line after the package name, before any `#` comment.
- Paths or package names with embedded spaces are not supported when using `@hostname` tags.

**Examples:**

```
# Installed on all machines
neovim

# Installed only on the host named 'armini'
postgresql      @armini

# Installed on 'arbook' and 'arpad', but not on 'armini'
steam           @arbook @arpad

# Inline comments work alongside hostname tags
virtualbox      @arbook    # only on the main workstation
```

The script detects the current machine's hostname at startup and automatically skips any entry whose tags don't match.

## Deduplication

Before acting on the package lists, the script automatically deduplicates entries in `packages-install.txt`, `packages-aur-install.txt`, and `packages-remove.txt`.

**Rules:**

- **Within-file**: if the same package name appears more than once in a file (untagged), all occurrences after the first are dropped. The first occurrence's inline comment is kept.
- **Cross-file**: if an untagged package name appears in an install file *and* in `packages-remove.txt`, it is removed from the install file and kept only in the remove list.
- **Tagged entries are skipped**: any entry carrying an `@hostname` tag is left untouched by both rules, preserving intentional splits like `postgresql @armini` (install on one host) alongside `postgresql @arbook @arpad` (remove on others).

Dropped entries are reported with `[WARN]`.

## Package List Sorting

After each run, the script alphabetically sorts `packages-install.txt`, `packages-aur-install.txt`, and `packages-remove.txt`. The leading comment/blank header block is preserved, inline comments and `@hostname` tags stay attached to their entry, and blank lines within the body are dropped.

## License

Licensed under the MIT License. See LICENSE for more information.

## Project status

This project is under periodic active development. It is not yet ready for production use, but it is being used on my personal machines and I am happy to share it with others who may find it useful. I welcome contributions and suggestions for improvement.
