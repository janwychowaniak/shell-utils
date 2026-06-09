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
  - 🟢 **tylko odczyt (safe RO)** — only reads/queries state; never mutates anything. Safe to run and experiment with freely. (e.g. `jwdocker_ps`, `jwdocker_*-inspect`, `jwdocker_logs`, `jwdocker_monitor-*`)
  - 🔵 **tworzy** — creates a resource (image, volume, network, container, file); typically reversible. (e.g. `jwdocker_image-pull`, `jwdocker_volume-create`, `jwdocker_run`, `jwdocker_save`)
  - ⚪ **zmiana stanu / transfer** — mutates existing state or moves data, but does **not** delete. (e.g. `jwdocker_container-start`/`-stop`/`-restart`, `jwdocker_network-connect`/`-disconnect`, `jwdocker_cp`, `jwdocker_push`, `jwdocker_exec`)
  - 🔴 **kasuje (destructive)** — removes or prunes resources; the "handle with care" class. (e.g. `jwdocker_*-remove`, `jwdocker_*-prune`, `jwdocker_cleanup`)
- The TOC opens with a legend line so the key is always at hand:
```bash
echo "   blast radius:  🟢 tylko odczyt   🔵 tworzy   ⚪ zmiana stanu / transfer   🔴 kasuje (destructive)"
```
- Per-entry format places the marker between the dash and the function name:
```bash
echo " - 🟢 jwdocker_psall"
echo " - 🔴 jwdocker_image-rm"
```
- When a function's class is ambiguous, classify conservatively — assign the higher-impact marker (e.g. a tool that opens an interactive shell is ⚪, not 🟢, because of what can be done inside it).

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
- Functions called without required parameters print helpful usage examples and `return 1`
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
- Timeout values, output limits, and common paths pre-configured
- Fallback behaviors when tools are unavailable

### Enhanced Output
- Consistent formatting with headers, separators, and sections using `---[ Title ]---` pattern
- Color output via the `jw_colors.sh` helpers (`jwpaintfgRed`, `jwpaintfgGreen`, …) rather than raw ANSI codes; emoji for status indicators (✅ ❌ ⚠️ 💡)
- Structured information display with clear labels
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
