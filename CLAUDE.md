# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A collection of Bash shell utility functions and aliases, sourced into the user's interactive shell via `.bashrc`/`.zshrc`. There is no build step, no test suite, and no package manager. Files are sourced directly.

## Conventions

The authoritative coding-convention spec for this repo lives in [`CONVENTIONS.md`](CONVENTIONS.md) — naming (public/internal/legacy), ShellCheck compliance, function & help patterns, safety rules, output style, cross-shell portability (bash + zsh), logical grouping, and the `<area>_toc()` blast-radius markers (🟢 read-only · 🔵 creates · ⚪ state change/transfer · 🔴 destructive). This file is a quick orientation (what the repo is, where things live); `CONVENTIONS.md` is the source of truth and wins on any conflict.

## Linting

```bash
shellcheck jw_functions__<area>.sh
```

All function files should include `# shellcheck shell=bash` at the top.

## Secret scanning

Secrets are scanned with [gitleaks](https://github.com/gitleaks/gitleaks) (apt 8.16).
A versioned pre-commit hook (`.githooks/pre-commit`) runs `gitleaks protect --staged`
and blocks commits that introduce secrets. Activate it once per clone:

```bash
git config core.hooksPath .githooks
```

Config is `.gitleaks.toml` (extends the default ruleset; add false positives to
`[allowlist]`). Ad-hoc scans: `gitleaks detect -v` (history),
`gitleaks detect --no-git -v` (files).

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
