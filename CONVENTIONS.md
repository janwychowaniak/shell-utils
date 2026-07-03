# Naming

### Function Prefix
- All functions use the `jw` prefix followed by the area identifier
- Examples: `jwdocker*`, `jwdeb*`, `jwgit*`
- Format: `jw<area>_<action>` (e.g., `jwdocker_container-start`, `jwdeb_install`, `jwgit_commit`)

### File Naming
- Files follow the pattern: `jw_functions__<area>.sh`
- Examples: `jw_functions__docker.sh`, `jw_functions__deb.sh`, `jw_functions__git.sh`

### Internal Helpers and Variables
- Internal helper functions: `__jw<name>__` — double underscores both sides (e.g. `__jwStyleGetMarker__`)
- Internal variables: `_jw<name>_` — single underscores both sides (e.g. `_jwStyleParamBold_`)

### Legacy Names
- Some older functions use Polish names (e.g. `jwodspacjacz` = space remover, `jwnotatki` = notes)

### Language — English-only prose
- **All prose authored in the repo is English**: comments, function help/usage text, user-facing `echo` output, and `<area>_toc()` group headers / legend / taglines. The working conversation may be in another language (e.g. Polish), but it must not leak into committed files.
- **Exception — legacy identifiers.** The Polish *function names* above (`jwodspacjacz`, `jwnotatki`) are grandfathered identifiers, not prose; they stay. New names follow `jw<area>_<action>` in English.

# Code Quality Standards

### ShellCheck Compliance
- All files include `# shellcheck shell=bash` at the top
- Code must pass shellcheck linting
- Proper quoting and variable handling

### Function Structure
- Functions are logically grouped within files using comment separators
- Clear section headers with dashes for visual organization
- Example:
```
# ---------------------------------------------------------------------------------
# volume management
# ---------------------------------------------------------------------------------
```
- Larger files should include a `<area>_toc()` function listing all functions by category

### Blast-radius Markers in the TOC
- Every function entry in `<area>_toc()` is prefixed with an emoji marker classifying its side effects, so the impact of a function is visible at a glance — without reading its code or remembering it. Four classes:
  - 🟢 **read-only (safe RO)** — only reads/queries state; never mutates anything. Safe to run and experiment with freely. (e.g. `jwdocker_ps`, `jwdocker_*-inspect`, `jwdocker_logs`, `jwdocker_monitor-*`)
  - 🔵 **creates** — creates a resource (image, volume, network, container, file); typically reversible. (e.g. `jwdocker_image-pull`, `jwdocker_volume-create`, `jwdocker_run`, `jwdocker_save`)
  - ⚪ **state change / transfer** — mutates existing state or moves data, but does **not** delete. (e.g. `jwdocker_container-start`/`-stop`/`-restart`, `jwdocker_network-connect`/`-disconnect`, `jwdocker_cp`, `jwdocker_push`, `jwdocker_exec`)
  - 🔴 **destructive** — removes or prunes resources; the "handle with care" class. (e.g. `jwdocker_*-remove`, `jwdocker_*-prune`, `jwdocker_cleanup`)
- The TOC opens with a legend line so the key is always at hand:
```bash
echo "   blast radius:  🟢 read-only   🔵 creates   ⚪ state change / transfer   🔴 destructive"
```
- Per-entry format places the marker between the dash and the function name — rendered via the per-area `__<area>_toc_row__` helper (see *TOC entry taglines* below), so the marker sits in a fixed slot ahead of the padded name + tagline:
```bash
__jwdocker_toc_row__ 🟢 jwdocker_psall   "all containers (run + stopped)"
__jwdocker_toc_row__ 🔴 jwdocker_image-rm "remove an image (in-use gate)"
```
- When a function's class is ambiguous, classify conservatively — assign the higher-impact marker (e.g. a tool that opens an interactive shell is ⚪, not 🟢, because of what can be done inside it).

### TOC entry taglines (soul-capture)
- Each `<area>_toc()` entry carries a short keyword **tagline** capturing what the function does at a glance — e.g. `jwweb_domain` → `RDAP-first + whois-fallback`, `jwweb_diag` → `DNS→TCP→TLS→HTTP→headers`. It makes the TOC self-documenting without opening any function.
- **Keyword-slogan, not a sentence** — ≤ ~30 chars, technical English, no trailing period.
- **Rendered via a per-area `__<area>_toc_row__` helper**, never hand-spaced:
```bash
__jwweb_toc_row__() { printf " - %s %-22s%s\n" "$1" "$2" "$3"; }   # marker, name, tagline
```
- **Alignment is static and hardcoded.** The tagline column starts **five spaces after the longest function name in that file**: `width = len(longest name) + 5` (web: `jwweb_cert-expiry` = 17 → `%-22s`). Compute it once per file and hardcode the width — the marker sits in a fixed `" - %s "` slot so it never shifts the column, and `printf` is byte-width so bash and zsh render identically (the bash↔zsh TOC parity check in the smoke test guards this).
- Pioneered in `jw_functions__web.sh`; now **backported to every** `<area>_toc()` function, each with its own statically-computed width — git `%-22s`, deb `%-23s`, python `%-25s`, docker `%-32s`.

### Cross-shell Portability (bash + zsh)
- Files are sourced into both bash and zsh, so code must behave identically in both. The key trap: **zsh does not word-split unquoted parameter expansions** by default (no `SH_WORD_SPLIT`), whereas bash does — so `cmd $scalar` passes one argument in zsh but several in bash.
- Never collect variadic arguments into a joined scalar and pass it unquoted (`OPTIONS="$*"; cmd $OPTIONS`) — that only "works" in bash. Forward the remaining positional parameters as an array instead; this is identical in both shells and also preserves values containing spaces:
```bash
shift 2                       # drop the fixed leading args
if [ $# -gt 0 ]; then
    echo "Options: $*"        # "$*" is fine for *display* only
    docker network connect "$@" "$NETWORK" "$CONTAINER"
else
    docker network connect "$NETWORK" "$CONTAINER"
fi
```
- To iterate a list, build an array (`items+=("$x")`) and loop with `for x in "${items[@]}"`, or read newline-separated text with `while IFS= read -r x; do ...; done <<< "$text"`. Never `for x in $scalar` — zsh treats the whole scalar as a single word.

**zsh runtime gotchas (these PARSE fine — they only break when the function RUNS):**
- **Reserved variable names:** never use `status`, `path`, `argv`, `options`, `pipestatus`, … as a `local`/`read`/loop variable. zsh makes them read-only/special (`status` mirrors `$?`), so it aborts at runtime with "read-only variable". Use `st`, `p`, etc.
- **Bare `local x` re-prints in zsh:** a bare `local x` (no assignment) that re-declares an already-set variable *prints* `x=value` (it lists the var). Because `while read`/`for` loops run in the current shell in zsh, an in-loop `local x` reprints the previous iteration's value, and a second `local x` after an earlier one leaks the stale value to stdout. **Declare each local once (at the top, or before the loop), or initialize it (`local x=""`)** — never a bare re-declaration.
- **`read -r line` trims leading whitespace** (IFS): it eats the leading space of `git status --porcelain` codes (` M` → `M `), shifting `cut -c` columns. Use `while IFS= read -r line`.
- **Verify by EXECUTING in both shells, not just `zsh -n`/`type`.** `tests/smoke_jwgit.sh` runs every function and (Part C) diffs bash-vs-zsh stdout — that parity check is what catches the gotchas above.

### ShellCheck Exceptions
- Forwarding variadic args via `"$@"` / arrays (see *Cross-shell Portability*) is the convention — it replaces the old `# shellcheck disable=SC2086` on an unquoted `$OPTIONS` scalar, which was bash-only.
- When an SC-disable is genuinely unavoidable, keep it narrowly scoped (one line) with a comment explaining why.

# User Experience Design

### Parameter Handling
- Functions with a **required** parameter, called without it, print helpful usage examples and `return 1`.
- **Read-only functions with a sensible default** (e.g. `jwgit_status`, `jwgit_log`, `jwgit_diff`, `jwgit_reflog`) must instead **run that default on no-args** — and expose the usage block via `-h`/`--help` (returning 0). Do NOT blanket the usage-on-no-args guard onto a defaulting function: it makes the help contradict itself ("`jwgit_log` # Show recent commits" while no-args actually printed help). Required-arg functions (`jwgit_clone`, `jwgit_merge`, `jwgit_blame`, `jwgit_branch create`, …) keep usage-on-no-args.
- **The shared help block (canonical idiom).** `-h`/`--help` prints the *same* usage block as no-args and `return 0` — never treated as data, never duplicated into a second block. Share one block, keyed by the function's shape:
```bash
# required-arg: no-args → 1, -h → 0
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: ..."; echo "Examples:"; echo "  ..."
    [ $# -eq 0 ] && return 1 || return 0
fi
# N required args (e.g. 2): too-few-args → 1, -h → 0
if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: ..."
    { [ "$1" = "-h" ] || [ "$1" = "--help" ]; } && return 0 || return 1
fi
# defaulting read-only: -h → 0 up top; no-args runs the default below
case "${1:-}" in -h|--help) echo "Usage: ..."; return 0 ;; esac
```
- **Footgun — a public command that is also an internal callee.** If a function references `$1` (e.g. for `-h`) *and* is called elsewhere in the file with no args, shellcheck flags SC2120/SC2119. This repo is zero-disable, so fix it structurally: move the body into an internal `__<area>_<name>__` worker, have the public function parse `-h` and delegate to it, and repoint the internal call sites at the worker. (Applied to `jwgit_status`, `jwdeb_dist-upgrade`, `jwdocker_volume-prune`/`network-prune`.)
- Display available options (running containers, installed packages, etc.)
- Provide multiple example use cases with different parameter combinations
- Two styles for no-args help:
  - **"Pick one" style**: print `\n\t???` then list available resources — used when the function just needs a target picked from a known set
  - **"Usage" style**: print `Usage:` / `Examples:` block — used when the function takes complex or multi-parameter input
- Help format template:
```bash
echo "Usage: jwdocker_image-build <tag> [dockerfile_path] [build_context]"
echo "Examples:"
echo "  jwdocker_image-build myapp:latest"
echo "  jwdocker_image-build myapp:v1.0 ./Dockerfile ."
```

### Safety Features
- Destructive operations require user confirmation
- Clear warnings for dangerous actions (e.g., `⚠️ WARNING: This will remove...`)
- Force flags available for automation (`force`, `-f`)
- Safety checks prevent accidental removal of active resources

### Default Values
- Reasonable defaults for optional parameters
- Timeout values and common paths pre-configured
- **Output limits — show everything; capping is opt-in.** Default to NO truncation anywhere — listing/viewer functions *and* summary/confirmation previews (e.g. install/remove showing every affected package) print the full result; the user narrows with their own `head`. NEVER cap a **dedicated viewer** (`jwgit_log`, `jwgit_reflog`, `jwdeb_installed`, …). A `head -N`/`tail -N` cap is added only when explicitly requested for a specific function (e.g. `jwdeb_diag`'s bounded "Recent Activity"). Not caps (keep these): `head -1`/`tail -1` single-field extraction and `tail -n +2` header strips. A silent, undocumented cap is a bug, not a default.
- Fallback behaviors when tools are unavailable

### Enhanced Output
- Consistent formatting with headers, separators, and sections using `---[ Title ]---` pattern
- Color output via the `jw_colors.sh` helpers (`jwpaintfgRed`, `jwpaintfgGreen`, …) rather than raw ANSI codes; emoji for status indicators (✅ ❌ ⚠️ 💡)
- Structured information display with clear labels
- **Column-align `Label: value` rows** in info/summary blocks via a tiny per-area helper `__jw<area>_kv__` instead of ragged `echo "Label: $val"`, so values line up in a column:
  ```bash
  __jwgit_kv__() { printf "%-${3:-18}s%s\n" "$1" "$2"; }   # 3rd arg = optional column width
  ```
  - The default width is tuned to the busiest block in the file; pass an explicit width for blocks whose longest label differs (so the gutter stays ~2 spaces — e.g. in git: blame `File Info`=8, prune `Maintenance Summary`=10, gc `Cleanup Summary`=16, everything else 18).
  - `printf` is byte-width and identical in bash + zsh, so keep **labels ASCII** (emoji only on non-aligned lines) and pass the value as the `%s` argument (a `%` or `—` in the value is then inert).
  - Apply only to **grouped rows (≥2 in one visual block)**; leave standalone single lines, `---[ ]---` headers, file/commit lists, and `💡` hints alone. Reference: `__jwgit_kv__` in `jw_functions__git.sh`.
- Progress indicators and completion summaries
- State-changing operations (start, stop, build, pull) should display the resulting state after the action completes

### Interactive Wizards
- Complex multi-choice operations may use an interactive menu pattern: show current state, present lettered options, act on choice, show final state
- Example: `jwdocker_cleanup()` — shows disk usage, lists cleanup options with counts, prompts for choice, shows result

# Logical Grouping

### Functional Categories
Functions are organized into logical groups within each area:

Docker Example:
- Container lifecycle (start, stop, restart, remove)
- Image management (pull, build, remove, history)
- Volume operations (create, inspect, remove, prune)
- Network management (create, connect, disconnect, remove)
- System maintenance (cleanup, monitoring, troubleshooting)

Debian Example:
- Package search and information
- Package management (install, remove, purge)
- System updates (update, upgrade, dist-upgrade)
- System maintenance (autoremove, autoclean, clean)
- Package analysis (installed, size, orphans)
- Troubleshooting (broken, fix, diagnostics)

# Lanes: imperative vs declarative

Areas that manage an environment's *contents* (today: `python`) split along one
axis — **where the authoritative state lives, and what you act on.** Two lanes,
plus orthogonal groups that sit on neither.

- **Imperative lane.** You act *on the environment directly*; commands mutate it
  *now* (`jwpy_install` / `jwpy_uninstall` / `jwpy_upgrade`). The environment **is**
  the state — there is no separate manifest of record. In python this is the
  *package management* + *dependency management* groups, both routed through
  `__jwpy_pip__` (uv pip / pip).
- **Declarative lane.** You act *on a manifest* (`pyproject.toml`); the lockfile
  (`uv.lock`) and `.venv` are **derived** from it (`uv lock` / `uv sync`). The
  manifest + lock are the **source of truth**; the environment is a reproducible
  artifact. In python this is the *uv project* group — oversight-skewed (status /
  sync / lock / tree / export); mutating the *declaration* itself (`uv add` /
  `remove`) is done with uv directly (see *Oversight-first*).

|                          | imperative                  | declarative                   |
|--------------------------|-----------------------------|-------------------------------|
| You act on               | the environment             | a manifest                    |
| Source of truth          | the env (installed set)     | pyproject + lock              |
| You express              | *how* (steps: install X)    | *what* (the desired set)      |
| Reproducible             | no — unless you `freeze`    | yes — deterministic from lock |
| Env ↔ spec reconciliation | manual round-trip (`freeze` ↔ `reqs-install`) | automatic (`uv sync`, `sync --check`) |

- **A file does not make a lane declarative.** `requirements.txt` keeps the pip
  group imperative. The test is not "is there a list file" but *"is the env derived
  and reconciled from an authoritative manifest+lock, or do you push commands at the
  env with files as mere snapshots?"* `requirements.txt` is a hand-managed snapshot
  (produced by `freeze`), with no lock and no reconciliation engine — file and env
  drift freely. Imperative.
- **Orthogonal groups** (on neither end of the axis): venv **lifecycle**
  (create / activate / remove — the *container* both lanes sit on); **pipx** (a
  different axis — global per-app scope, not project scope); **code quality** (runs
  tools, does not manage deps).
- **Why the axis exists — it is enforced in exactly one place.** Mixing lanes is a
  footgun: in a uv (declarative) project an ad-hoc imperative `pip install` is not
  in the lock, and `uv sync` will revert it. That single hazard is the entire reason
  for `__jwpy_lane_caveat__` / `__jwpy_lane_guard__`.

**Vocabulary — keep these two axes disjoint.** *imperative / declarative **lane*** is
this state-management axis (above). The *side-effect* axis — whether a function reads
or mutates — is the **blast-radius markers** (🟢 vs 🔵 ⚪ 🔴); call those functions
**mutators** or **"doing"-wrappers**, never "imperative", so the two axes don't blur.

# Intelligence Features

### Filtering and Search
- Pattern matching with case-insensitive search
- Multiple filter options (--installed, --names-only, --size, etc.)
- Intelligent suggestions based on context
- Tab-completion friendly function names

### Context Awareness
- Show relevant available options when parameters are missing
- Display recent activity (installations, logs, etc.)
- Provide related command suggestions
- Integration with system state (running containers, installed packages)

### Error Handling
- Graceful degradation when tools are unavailable
- Clear error messages with suggested solutions
- Alternative methods when primary tools fail
- Helpful troubleshooting guidance

# Documentation Standards

### Inline Help
- Usage examples for each function
- Parameter explanations and options
- Common use case demonstrations
- Related function suggestions

### Code Comments
- Section headers for functional groupings
- Complex logic explanation
- Safety consideration notes
- Integration points with external tools

### Self-contained tool prose
- **A tool file's comments and `-h`/usage describe its OWN tools only.** No
  editorializing about what an agent does elsewhere ("renaming is the agent's
  job"), and no pointing at other files the tool doesn't use — say it plainly
  ("reports only", "read-only"). Design docs (this file, `CLAUDE.md`, the memory
  store) may discuss the agent-era lens and cross-area comparisons; a tool's own
  prose may not — a sourced file should stand on its own.

# Consistency Patterns

### Command Structure
- Consistent parameter ordering across similar functions
- Standard flag conventions (--force, --verbose, --help)
- Uniform output formatting patterns
- Predictable behavior across different areas

### Status Reporting
- Consistent success/failure indicators
- Standardized progress reporting
- Uniform summary formats
- Common troubleshooting patterns

# Bringing a New Area to Production Quality

Each `jw_functions__<area>.sh` is taken through the same pipeline (git → deb →
docker have followed it). Not every step always applies — assess the file first.

1. **Baseline commit** the file's current state.
2. **Naming** — `jw<area>_<action>` with the separator; fix any misnomers.
3. **TOC** — author a `<area>_toc()` *function* (not a comment) with the
   blast-radius markers + legend (see *Blast-radius Markers in the TOC*).
4. **Audit** for the bash/zsh runtime traps (see *Cross-shell Portability*).
   Parallel sub-readers over disjoint function groups are fine, but
   **self-verify every high-severity claim before acting** — sub-agents
   false-positive (a git "inverted merge logic" finding was wrong on inspection).
5. **Remediate group by group**, one commit per group, shellcheck-clean and
   *run* (not just `-n`) in **both bash and zsh** after each.
6. **Fill domain gaps** with the functions the area obviously lacks.
7. **Smoke test** `tests/smoke_<area>.sh` (model on the siblings): no-args of
   every function + bash↔zsh stdout parity of the deterministic read-only ones.
   Never mutate real system/daemon state. **Make the fixture rich enough to drive
   loops past one iteration** — a single-element fixture once hid 3 zsh bugs.

## From scratch (greenfield)

The pipeline above is *remediation-shaped*: it assumes an existing raw file whose
function set is given and whose work is correctness + standardization. A net-new
area (e.g. the ideas in `_further_areas.md`) inverts it — the **design is the
work**, and the conventions are written in from line one. The quality bar and
everything tool-agnostic (naming, TOC + markers, Cross-shell Portability,
no-caps, smoke + bash↔zsh parity, commit-per-group, verify-by-running) is
identical; only the process changes:

- **First, check for raw material.** A scratch draft (like the docker dev-helpers)
  is remediation-of-a-draft — use the pipeline as-is. Only a truly-empty area is
  greenfield.
- **Design before code, with sign-off.** Decide the function set, what each does,
  its blast-radius and UX, and confirm it — `_further_areas.md`-style lists are
  wishlists, not specs. This replaces steps 1/4 (nothing to baseline or audit yet).
- **Demand-driven and incremental.** Build the 2–3 functions you will actually
  use, validate the shape, then grow — not a completeness sweep of the wishlist.
- **No behavioral reference.** There is no "old version" to diff against, so
  "correct" means "matches the design intent"; verification leans entirely on the
  smoke test + the agreed spec.
- **Prevention, not correction.** The bash/zsh trap list is an authoring guide
  here, not an audit pass — write it right the first time.

# Oversight-first (the agent-era lens)

Code is increasingly written *through agents*, so a function's value is judged by
**who actually invokes it — the human at the terminal, or an agent in its own
subprocess.** That reshapes what is worth building:

- **Default to oversight.** The highest-value functions answer *"what's the
  state?"* — read-only profilers / status / listers (🟢). A human supervising
  agents reaches for these constantly. The blast-radius markers already *are* this
  map: everything 🟢 is the oversight toolkit; 🔵 ⚪ 🔴 is the "doing" layer.
- **Prize the agent-impossible.** Anything that manipulates the *interactive
  shell's own state* (e.g. `jwpy_venv-activate` / `-deactivate`, which `source` a
  venv so it persists after the function returns) is something an agent
  fundamentally **cannot** do in your shell — the most justified functions of all.
- **Be wary of "doing" wrappers.** Mutators (install / add / build / publish /
  format — the side-effect axis, not the imperative/declarative *lane*) are usually
  run by the agent directly, so a thin re-spelling
  adds little. Build one only when it adds a **guard or transparency the raw
  command lacks** — e.g. a system-Python guard, a lane-mixing warning, or a
  `· active venv` source annotation — never just to rename a command the agent
  already types. **And don't reimplement a mature packaged tool:** if an
  apt-installable tool already does the job (`fdupes`, `duf`, …), prefer it and
  drop the bespoke wrapper — Occam over NIH. (Dropped `jwfs_dupes` → `fdupes -r`,
  `jwfs_disk` → `duf`.)
- **Show a would-be mutation; don't silently do it.** In an oversight-first /
  mostly-🟢 area the file promises *"safe to run (almost) anything blindly"* — that
  low cognitive load *invites* a reflexive call, so the rare mutator must not betray
  the contract. Two shapes: (a) **print-the-command** (stays 🟢) — emit the exact
  runnable command, pipeable to a shell (`jwfs_backup` prints its `cp`); (b)
  **dry-run + `--execute`/`-x`** (⚪) — print the plan by default, apply only with
  the flag (`jwfs_rename`, `jwfs_flatten`). The terraform/rsync "see it first" model.
  **Scope it deliberately:** the guard exists to protect the *"run it blindly"*
  contract, so it belongs in oversight-first areas — NOT the older mutation-heavy /
  many-colored files, where you already act with deliberation and the guard is
  friction without benefit. The safeguard's value tracks the likelihood of a
  careless call; match it to the mental mode the file is used in.
- **Forward rule, not a retroactive purge.** This governs what to *add*; existing
  doing-wrappers that carry real guards stay (they cost nothing and serve the
  occasional ad-hoc interactive moment). Concretely, this lens is why the uv lane
  is oversight-only (no `jwpy_uv-add` / `-remove` — uv does those), and why there
  is no local `jwpy_publish` (PyPI Trusted Publishing keeps the credential-bearing
  upload on the CI runner; a local publish would bypass that chain).
