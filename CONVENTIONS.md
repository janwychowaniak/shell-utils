# Naming

### Function Prefix
- All functions use the `jw` prefix followed by the area identifier
- Examples: `jwdocker*`, `jwdeb*`, `jwgit*`
- Format: `jw<area>_<action>` (e.g., `jwdocker_container-start`, `jwdeb_install`, `jwgit_commit`)

### File Naming
- Files follow the pattern: `jw_functions__<area>.sh`
- Examples: `jw_functions__docker.sh`, `jw_functions__deb.sh`, `jw_functions__git.sh`

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

### ShellCheck Exceptions
- Use `# shellcheck disable=SC2086` when passing an `$OPTIONS` variable unquoted to allow multi-word flags through to underlying commands

# User Experience Design

### Parameter Handling
- Functions called without required parameters show helpful usage examples
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
- Color coding and emoji for status indicators (✅ ❌ ⚠️ 💡)
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
