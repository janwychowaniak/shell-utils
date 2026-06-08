# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A collection of Bash shell utility functions and aliases, sourced into the user's interactive shell via `.bashrc`/`.zshrc`. There is no build step, no test suite, and no package manager. Files are sourced directly.

## Conventions

The authoritative coding-convention spec for this repo lives in [`CONVENTIONS.md`](CONVENTIONS.md) — naming, ShellCheck compliance, function/help patterns, safety rules, logical grouping, and the `<area>_toc()` blast-radius markers (🟢 read-only · 🔵 creates · ⚪ state change/transfer · 🔴 destructive). The sections below are a condensed orientation; when the two disagree, `CONVENTIONS.md` wins.

## Linting

```bash
shellcheck jw_functions__<area>.sh
```

All function files should include `# shellcheck shell=bash` at the top.

## Architecture

**Files are organized by domain** following the pattern `jw_functions__<area>.sh`:

| File | Domain |
|------|--------|
| `jw_functions__git.sh` | Git wrapper functions (`jwgit*`) |
| `jw_functions__deb.sh` | Debian/apt package management (`jwdeb*`) |
| `jw_functions__docker.sh` | Docker operations (`jwdocker*`) |
| `jw_functions__fs.sh` | File system / file naming (`jwdiff`, `jwodspacjacz*`, etc.) |
| `jw_functions__media.sh` | Media notes/templates (sox, etc.) |
| `jw_functions__mediaff.sh` | FFmpeg/ffprobe functions (`jwff*`) |
| `jw_functions__mediaim.sh` | ImageMagick functions (`jwim*`) |
| `jw_functions__misc.sh` | Uncategorized utilities (`jwpaste`, `jwai_jina`, etc.) |
| `jw_functions__prog.sh` | Programming helpers (`jwvec*`, `jwc*`) |
| `jw_aliases.sh` | Shell aliases |
| `jw_colors.sh` | ANSI color/style helpers (`jwpaintfg*`, `__jwStyle*`) |

## Naming Conventions

- **Public functions**: `jw<area>_<action>` (e.g., `jwdocker_container-start`, `jwdeb_install`, `jwgitcommit`)
- **Internal helpers**: `__jw<name>__` with double underscores (e.g., `__jwStyleGetMarker__`)
- **Internal variables**: `_jw<name>_` with single underscores (e.g., `_jwStyleParamBold_`)
- **New files**: `jw_functions__<area>.sh`
- Some older functions use Polish names (e.g., `jwodspacjacz` = space remover, `jwnotatki` = notes)

## Function Patterns

Every function that takes parameters must show usage/examples when called with no arguments (or wrong argument count), printing to stderr and returning 1. Example:

```bash
jwexample() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwexample <arg> [options]"
        echo "Examples:"
        echo "  jwexample foo"
        echo "  jwexample bar --verbose"
        return 1
    fi
    # ... implementation
}
```

Destructive operations must prompt for user confirmation. Force flags (`force`, `-f`) bypass confirmation for automation.

Within each file, functions are grouped under comment-block section headers:
```bash
# ---------------------------------------------------------------------------------
# section name
# ---------------------------------------------------------------------------------
```

The git and docker files include a table of contents at the top listing all functions.

## Color Output

Use the helpers from `jw_colors.sh` for colored output (e.g., `jwpaintfgRed`, `jwpaintfgGreen`). Status indicators use emoji: checkmark, X, warning, lightbulb.
