# shell-utils

This repository is a collection of shell utility functions and aliases, grouped by
domain and sourced straight into your interactive shell — **bash or zsh**, with no
build step and no package manager. Each one wraps a standard CLI tool behind a short,
consistent, safety-conscious command.

## What's inside

Every area is namespaced by a `jw…` prefix. The seven newer areas (Git through
Processes/services) are self-documenting — each ships a table-of-contents function and
per-command `-h` help; see [Using the functions](#using-the-functions).

| Area | Prefix | What it does |
|------|--------|--------------|
| Git | `jwgit_*` | Git workflow wrappers — branch / commit / rebase / stash / log / … |
| Docker | `jwdocker_*` | Container / image / volume / network operations |
| Debian · apt | `jwdeb_*` | Package management, search & inspection |
| Python | `jwpy_*` | Virtualenvs, packages & projects — uv / pip / pipx |
| Web · API | `jwweb_*` | HTTP / TLS / DNS / connectivity diagnostics |
| Filesystem | `jwfs_*` | Read-only orientation & profiling + guarded cwd mutators |
| Processes · services | `jwps_*` | Live-runtime oversight — processes, ports, sockets, systemd units |
| Media | `jwff*` · `jwim*` · `jwsox` · … | ffmpeg / ImageMagick / sox cheat-sheets & batch helpers |
| Misc | `jwpaste` · `jwai_jina` · … | Uncategorised odds and ends |

Plus `jw_aliases.sh` (shell aliases) and `jw_colors.sh` (ANSI colour/style helpers).

## Requirements

Bash or Zsh — the functions are written and smoke-tested to run in both. They lean on
the standard tool for each area, so install whatever you actually use: e.g. `git`,
`docker`, `apt`, `uv`, `curl` / `openssl` / `dig`, `ss` / `systemctl`, and
`ffmpeg` / `imagemagick` / `sox` / `libimage-exiftool-perl` for the media helpers.

## Installation suggestions

E.g. in `~/bin`:

```bash
cd ~/bin
git clone https://github.com/janwychowaniak/shell-utils.git
```
Then add a single line to your `~/.bashrc` or `~/.zshrc` (identical for both shells):

```bash
[ -f "$HOME/bin/shell-utils/load.sh" ] && . "$HOME/bin/shell-utils/load.sh"
```

`load.sh` finds its own directory and sources every area file for you, so that one line
never has to change: adding or removing an area is picked up on your next `git pull`, and
your shell rc stays untouched. (Cloned somewhere other than `~/bin/shell-utils`? Just point
that one line at wherever `load.sh` lives.)

## Using the functions

The seven newer areas are built to be self-documenting:

- **`<area>_toc`** — lists every command in that area with a one-line description and a
  blast-radius marker. One per area: `jwgit_toc` · `jwdocker_toc` · `jwdeb_toc` ·
  `jwpy_toc` · `jwweb_toc` · `jwfs_toc` · `jwps_toc`.
- **`-h` / `--help`** — every command in these areas prints its own usage, options and examples.
- **Tab-completion** — type a prefix (`jwps_`, `jwgit_`, …) and press Tab to browse.

The blast-radius marker in each TOC says at a glance what a command does:

> 🟢 read-only  ·  🔵 creates  ·  ⚪ state change / transfer  ·  🔴 destructive

(The media and misc files are older note / command-template collections — run one to
print its cheat-sheet.)
