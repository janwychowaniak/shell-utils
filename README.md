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
And then `.bashrc` (or `.zshrc` — the snippet is identical for both shells) might be appended with the following:

```bash
[[ -f "$HOME/bin/shell-utils/jw_aliases.sh" ]]            && . "$HOME/bin/shell-utils/jw_aliases.sh"
[[ -f "$HOME/bin/shell-utils/jw_colors.sh" ]]             && . "$HOME/bin/shell-utils/jw_colors.sh"
#
[[ -f "$HOME/bin/shell-utils/jw_functions__docker.sh" ]]  && . "$HOME/bin/shell-utils/jw_functions__docker.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__git.sh" ]]     && . "$HOME/bin/shell-utils/jw_functions__git.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__deb.sh" ]]     && . "$HOME/bin/shell-utils/jw_functions__deb.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__python.sh" ]]  && . "$HOME/bin/shell-utils/jw_functions__python.sh"
#
[[ -f "$HOME/bin/shell-utils/jw_functions__web.sh" ]]     && . "$HOME/bin/shell-utils/jw_functions__web.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__fs.sh" ]]      && . "$HOME/bin/shell-utils/jw_functions__fs.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__ps.sh" ]]      && . "$HOME/bin/shell-utils/jw_functions__ps.sh"
#
[[ -f "$HOME/bin/shell-utils/jw_functions__media.sh" ]]   && . "$HOME/bin/shell-utils/jw_functions__media.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__mediaff.sh" ]] && . "$HOME/bin/shell-utils/jw_functions__mediaff.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__mediaim.sh" ]] && . "$HOME/bin/shell-utils/jw_functions__mediaim.sh"
[[ -f "$HOME/bin/shell-utils/jw_functions__misc.sh" ]]    && . "$HOME/bin/shell-utils/jw_functions__misc.sh"
```

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
