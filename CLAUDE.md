# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A collection of Bash shell utility functions and aliases, sourced into the user's interactive shell via `.bashrc`/`.zshrc` — a single rc line sources `load.sh` (the loader), which sources each area file in turn. There is no build step and no package manager — files are sourced directly. Verification is via per-area smoke tests (`tests/smoke_<area>.sh`) run in both bash and zsh; there is no CI suite.

## Conventions

The authoritative coding-convention spec for this repo lives in [`CONVENTIONS.md`](CONVENTIONS.md) — naming (public/internal/legacy), ShellCheck compliance, function & help patterns, safety rules, output style, cross-shell portability (bash + zsh), logical grouping, the imperative-vs-declarative lane model, and the `<area>_toc()` blast-radius markers (🟢 read-only · 🔵 creates · ⚪ state change/transfer · 🔴 destructive). This file is a quick orientation (what the repo is, where things live); `CONVENTIONS.md` is the source of truth and wins on any conflict.

## Linting

```bash
shellcheck jw_functions__<area>.sh
```

All function files should include `# shellcheck shell=bash` at the top.

## Testing

Per-area smoke tests live in `tests/smoke_<area>.sh` (e.g. `smoke_jwgit.sh`,
`smoke_web.sh`). Each builds a throwaway fixture, runs every function under
**both bash and zsh**, scans for shell runtime-error signatures, and diffs
bash-vs-zsh stdout of the deterministic read-only functions (cross-shell
parity). Run after any change:

```bash
bash tests/smoke_<area>.sh
```

## Secret scanning

Secrets are scanned with [gitleaks](https://github.com/gitleaks/gitleaks) (apt 8.16),
in **defense-in-depth layers** — three local hooks plus a server-side CI scan.

Three versioned hooks guard the working machine — activate all three at once with
the single `core.hooksPath` setting below:
- `.githooks/pre-commit` runs `gitleaks protect --staged` — blocks secrets in
  staged **file content**.
- `.githooks/commit-msg` runs `gitleaks detect --no-git` on the message file —
  blocks secrets in the **commit message** itself. This covers the gap the
  staged-file scan cannot see: text pasted or dumped into the message body (an
  accidental `typeset`/`env` capture) never touches a file, so `protect --staged`
  is blind to it. That exact vector once leaked a full environment here.
- `.githooks/pre-push` re-scans the whole **pushed range** — content *and* commit
  messages — as the last check before anything leaves the machine (catches commits
  made with `--no-verify` or by a tool that ignored the per-commit hooks).

```bash
git config core.hooksPath .githooks
```

Local hooks are advisory — `--no-verify`, a `hooksPath`-ignoring tool, or a machine
without gitleaks all skip them. The **non-bypassable** layer is
`.github/workflows/gitleaks.yml`: it runs server-side on every push + PR + a weekly
sweep, scanning full-history content *and* all commit messages, and fails the check
on any finding.

Config is `.gitleaks.toml` — `[extend] useDefault = true` keeps the full built-in
ruleset and adds `jw-`prefixed provider rules on top (nothing built-in is disabled).
Add false positives to `[allowlist]`. Ad-hoc scans: `gitleaks detect -v` (history),
`gitleaks detect --no-git -v` (files).

## Architecture

**Files are organized by domain** following the pattern `jw_functions__<area>.sh`:

| File | Domain |
|------|--------|
| `jw_functions__git.sh` | Git wrapper functions (`jwgit*`) |
| `jw_functions__deb.sh` | Debian/apt package management (`jwdeb*`) |
| `jw_functions__docker.sh` | Docker operations (`jwdocker*`) |
| `jw_functions__python.sh` | Python virtualenvs, packages, projects & tooling — uv/pip/pipx (`jwpy_*`) |
| `jw_functions__web.sh` | Web/API diagnostics — HTTP/TLS/DNS/connectivity, oversight-first/diag-first (`jwweb_*`) |
| `jw_functions__fs.sh` | Filesystem cockpit — read-only orientation/profiling (size, recency, tree, search, posture, hygiene) + print-only backup + two ⚪ cwd mutators (rename/flatten, dry-run by default); oversight-first, server-safe (`jwfs_*`) |
| `jw_functions__ps.sh` | Live-runtime cockpit — process/port/resource/service oversight (find, tree, listening sockets + owners, top consumers, systemd unit status/journal + copy-paste commands); almost all 🟢 read-only + one guarded 🔴 `jwps_kill` (dry-run default, `--execute`); ps/ss/free/pstree/systemctl/journalctl, oversight-first, server-safe (`jwps_*`) |
| `jw_functions__media.sh` | Media notes/templates (sox, etc.) |
| `jw_functions__mediaff.sh` | FFmpeg/ffprobe functions (`jwff*`) |
| `jw_functions__mediaim.sh` | ImageMagick functions (`jwim*`) |
| `jw_functions__misc.sh` | Uncategorized utilities (`jwpaste`, `jwai_jina`, etc.) |
| `jw_aliases.sh` | Shell aliases |
| `jw_colors.sh` | ANSI color/style helpers (`jwpaintfg*`, `__jwStyle*`) |
| `load.sh` | Loader — self-locating (bash `BASH_SOURCE` / zsh `$0`); sources every area file from an explicit, ordered list. Users source this ONE file from their rc. **Adding/removing an area = update this list too.** |
