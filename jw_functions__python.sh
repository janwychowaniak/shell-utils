# shellcheck shell=bash
#
# Python / virtual-environment helpers (jwpy_*)
# =============================================
# Backend policy: prefer `uv` when installed (fast), fall back to the stdlib
# `python3 -m venv` + `pip`. Activation works because these files are *sourced*
# into the interactive shell, so `jwpy_venv-activate` can `source` a venv's
# activate script and have it persist after the function returns.


# ---------------------------------------------------------------------------------
# table of contents
# ---------------------------------------------------------------------------------

jwpy_toc() {
    echo
    echo "   blast radius:  🟢 tylko odczyt   🔵 tworzy   ⚪ zmiana stanu / transfer   🔴 kasuje (destructive)"
    echo
    echo " -----------------------------  virtual environment lifecycle"
    echo " - 🔵 jwpy_venv-create"
    echo " - ⚪ jwpy_venv-activate"
    echo " - ⚪ jwpy_venv-deactivate"
    echo " - 🔴 jwpy_venv-remove"
    echo " - 🟢 jwpy_venv-list"
    echo " - 🟢 jwpy_venv-info"
    echo
    echo " -----------------------------  package management (pip)"
    echo " - ⚪ jwpy_install"
    echo " - ⚪ jwpy_upgrade"
    echo " - 🔴 jwpy_uninstall"
    echo " - 🟢 jwpy_list"
    echo " - 🟢 jwpy_outdated"
    echo " - 🟢 jwpy_show"
    echo
    echo " -----------------------------  dependency management"
    echo " - 🟢 jwpy_freeze"
    echo " - 🔵 jwpy_reqs-save"
    echo " - ⚪ jwpy_reqs-install"
    echo
    echo " -----------------------------  interpreter & version info"
    echo " - 🟢 jwpy_version"
    echo " - 🟢 jwpy_which"
    echo " - 🟢 jwpy_pythons"
    echo
    echo " -----------------------------  code quality"
    echo " - 🟢 jwpy_test"
    echo " - 🟢 jwpy_lint"
    echo " - 🟢 jwpy_typecheck"
    echo " - ⚪ jwpy_format"
    echo
    echo " -----------------------------  pipx global tools"
    echo " - 🔵 jwpy_pipx-install"
    echo " - ⚪ jwpy_pipx-upgrade"
    echo " - 🔴 jwpy_pipx-uninstall"
    echo " - 🟢 jwpy_pipx-list"
    echo
}


# ---------------------------------------------------------------------------------
# internal helpers
# ---------------------------------------------------------------------------------

# Column-align "Label: value" rows. 3rd arg overrides the default width.
__jwpy_kv__() {
    printf "%-${3:-14}s%s\n" "$1" "$2"
}

# Resolve a venv directory. With $1: treat it as an explicit dir/name (echoed as
# given). Without: auto-discover the conventional names (.venv/venv/env) walking UP
# from the cwd to the filesystem root, like uv — so it works from a project subdir.
# Echoes the venv dir (absolute when discovered) + returns 0; returns 1 if none.
__jwpy_venv_find__() {
    local cand dir
    if [ -n "${1:-}" ]; then
        if [ -f "$1/bin/activate" ]; then
            printf '%s\n' "$1"
            return 0
        fi
        return 1
    fi
    dir=$PWD
    while : ; do
        for cand in .venv venv env; do
            if [ -f "$dir/$cand/bin/activate" ]; then
                printf '%s\n' "$dir/$cand"
                return 0
            fi
        done
        [ "$dir" = "/" ] && break
        dir=${dir%/*}
        [ -z "$dir" ] && dir="/"
    done
    return 1
}

# THE environment resolver — single source of truth for "which environment", in the
# uv precedence model. Echoes "<kind>\t<root>"; rc 0 = a venv, rc 1 = system.
#   active venv -> "active\t$VIRTUAL_ENV"
#   project     -> "venv\t<dir>"   (auto-discovered, walking up like uv)
#   system      -> "system\t"      (no root)
__jwpy_envroot__() {
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        printf 'active\t%s\n' "$VIRTUAL_ENV"
        return 0
    fi
    local d
    if d=$(__jwpy_venv_find__); then
        printf 'venv\t%s\n' "$d"
        return 0
    fi
    printf 'system\t\n'
    return 1
}

# Run pip via the chosen backend. With uv: `uv pip` (uv resolves active > project
# .venv > system itself). Without uv: run pip with the env's resolved python (so a
# non-activated project .venv is honored too, and we never assume a bare `python`).
__jwpy_pip__() {
    if command -v uv >/dev/null 2>&1; then
        uv pip "$@"
        return
    fi
    local kind root py
    IFS=$'\t' read -r kind root <<<"$(__jwpy_envroot__)"
    if [ -n "$root" ] && [ -x "$root/bin/python" ]; then
        py="$root/bin/python"
    else
        py=$(command -v python3 || command -v python)
    fi
    if [ -z "$py" ]; then
        echo "❌ no python found to run pip." >&2
        return 1
    fi
    "$py" -m pip "$@"
}

# Describe which environment pip ops will affect (for display + the guard), via the
# shared resolver. Returns 0 for a venv, 1 for the system Python.
__jwpy_target__() {
    local kind root
    IFS=$'\t' read -r kind root <<<"$(__jwpy_envroot__)"
    case "$kind" in
        active) printf '%s\n' "$root (active venv)"; return 0 ;;
        venv)   printf '%s\n' "$root (.venv, not activated)"; return 0 ;;
        *)      printf '%s\n' "SYSTEM Python"; return 1 ;;
    esac
}

# True if any argument looks like a path (not a -flag). Used to decide whether to
# append a default "." target for lint/format.
__jwpy_has_path__() {
    local a
    for a in "$@"; do
        case "$a" in -*) ;; *) return 0 ;; esac
    done
    return 1
}

# True if the resolved tool path is pipx-managed (its real path lives in a pipx venv)
# — i.e. a global standalone app, not a project tool that belongs in your venv.
__jwpy_is_pipx__() {
    local real
    real=$(readlink -f "$1" 2>/dev/null) || real="$1"
    case "$real" in
        */pipx/venvs/*) return 0 ;;
        *)              return 1 ;;
    esac
}

# Resolve a code-quality tool by ENVIRONMENT (via __jwpy_envroot__), never crossing
# the boundary: a tool from the active/discovered venv, or — only when there is no
# venv at all — a global one. Echoes "<source>\t<path>" (source "active venv" /
# "venv: DIR" / "global"), returns 0. Venv present but tool missing -> hint + return 1
# (no global fallback). No venv and nothing on PATH -> bare error + return 1.
__jwpy_tool__() {
    local kind root vbin="" src="" t
    IFS=$'\t' read -r kind root <<<"$(__jwpy_envroot__)"
    case "$kind" in
        active) vbin="$root/bin"; src="active venv" ;;
        venv)   vbin="$root/bin"; src="venv: $root" ;;
    esac

    if [ -n "$vbin" ]; then
        for t in "$@"; do
            [ -x "$vbin/$t" ] && { printf '%s\t%s\n' "$src" "$vbin/$t"; return 0; }
        done
        echo "❌ $1 is not installed in this venv ($root)." >&2
        echo "💡 Install it:  jwpy_install $1" >&2
        return 1
    fi

    for t in "$@"; do
        command -v "$t" >/dev/null 2>&1 && { printf '%s\t%s\n' "global" "$(command -v "$t")"; return 0; }
    done
    echo "❌ $1 not found (no virtualenv here)." >&2
    return 1
}

# Confirm before a mutating pip op that would modify the system Python.
__jwpy_guard_venv__() {
    if __jwpy_target__ >/dev/null; then
        return 0
    fi
    echo "⚠️  No virtual environment active — this would modify the SYSTEM Python."
    echo -n "Proceed against system Python? [y/N] "
    local reply
    read -r reply
    case "$reply" in
        y|Y) return 0 ;;
        *)   echo "Operation cancelled.  💡 jwpy_venv-activate first."; return 1 ;;
    esac
}

# Ensure pipx is available — the GLOBAL standalone-app lane. pipx installs each app
# into its own isolated venv (independent of any project venv), so NONE of the
# venv/precedence resolution above applies to the jwpy_pipx-* wrappers. Returns 1
# with an install hint if pipx is absent (graceful degradation).
__jwpy_pipx__() {
    command -v pipx >/dev/null 2>&1 && return 0
    echo "❌ pipx is not installed (needed for global CLI-tool management)." >&2
    echo "💡 Install it:  sudo apt install pipx   (or: python3 -m pip install --user pipx)" >&2
    return 1
}

# Re-align pipx's 3-line "venvs / apps / man" header into a padded column (label + ':'
# then the path), preserving pipx's bold on the paths, and pass every other line
# through verbatim. Reads pipx's (pty-captured) `list` output on stdin; strips the
# pty's carriage returns and the cursor hide/show codes pipx brackets its output with.
# Width 35 = longest label ("apps are exposed on your $PATH at") + ':' + a 1-col gutter.
__jwpy_pipx_list_align__() {
    awk '
        BEGIN {
            lbl[1] = "venvs are in"
            lbl[2] = "apps are exposed on your $PATH at"
            lbl[3] = "manual pages are exposed at"
        }
        { gsub(/\r/, ""); gsub(/\033\[\?25[lh]/, "") }   # drop CR + cursor hide/show
        /^\033\[0m$/ { next }                            # drop the trailing lone reset
        {
            for (i = 1; i <= 3; i++)
                if (index($0, lbl[i] " ") == 1) {
                    printf "%-35s%s\n", lbl[i] ":", substr($0, length(lbl[i]) + 2)
                    next
                }
            print
        }
    '
}


# ---------------------------------------------------------------------------------
# virtual environment lifecycle
# ---------------------------------------------------------------------------------

jwpy_venv-create() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwpy_venv-create <name|.venv> [--python X.Y] [--system-site-packages]"
        echo "Examples:"
        echo "  jwpy_venv-create .venv                 # conventional project venv"
        echo "  jwpy_venv-create myenv                 # named venv ./myenv"
        echo "  jwpy_venv-create .venv --python 3.12   # pin interpreter (needs that python)"
        echo
        echo "Backend: uv if installed (fast), else python3 -m venv."
        echo
        [ $# -eq 0 ] && return 1
        return 0
    fi

    local name=".venv"
    local pyver=""
    local extra=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --python)   pyver="${2:-}"; shift 2 ;;
            --python=*) pyver="${1#*=}"; shift ;;
            -*)         extra+=("$1"); shift ;;
            *)          name="$1"; shift ;;
        esac
    done

    if [ -e "$name" ]; then
        echo "⚠️  '$name' already exists — refusing to overwrite."
        echo "💡 Pick another name, or remove the existing one first."
        return 1
    fi

    echo "🐍 Creating virtual environment..."
    __jwpy_kv__ "Name:" "$name"
    [ -n "$pyver" ] && __jwpy_kv__ "Python:" "$pyver"

    local rc
    if command -v uv >/dev/null 2>&1; then
        __jwpy_kv__ "Backend:" "uv"
        if [ -n "$pyver" ]; then
            uv venv --python "$pyver" "${extra[@]}" "$name"
        else
            uv venv "${extra[@]}" "$name"
        fi
        rc=$?
    else
        local py="python3"
        [ -n "$pyver" ] && py="python$pyver"
        if ! command -v "$py" >/dev/null 2>&1; then
            echo "❌ interpreter '$py' not found"
            return 1
        fi
        __jwpy_kv__ "Backend:" "$py -m venv"
        "$py" -m venv "${extra[@]}" "$name"
        rc=$?
    fi

    if [ "$rc" -eq 0 ]; then
        echo "✅ Created '$name'"
        echo "💡 Activate it:  jwpy_venv-activate $name"
    else
        echo "❌ Failed to create virtual environment"
        return 1
    fi
    echo
}


jwpy_venv-activate() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_venv-activate [name|path]"
            echo "Examples:"
            echo "  jwpy_venv-activate           # auto-find .venv / venv / env in cwd"
            echo "  jwpy_venv-activate myenv     # activate ./myenv"
            echo "  jwpy_venv-activate ../proj/.venv"
            echo
            return 0
            ;;
    esac

    if [ -n "${VIRTUAL_ENV:-}" ]; then
        echo "ℹ️  A virtual environment is already active:"
        __jwpy_kv__ "Active:" "$VIRTUAL_ENV"
        echo "💡 Deactivate first (run: deactivate), then re-activate."
        return 1
    fi

    local vdir
    if ! vdir=$(__jwpy_venv_find__ "${1:-}"); then
        if [ -n "${1:-}" ]; then
            echo "❌ No venv found at '$1' (expected '$1/bin/activate')"
        else
            echo "❌ No virtual environment found in $(pwd)"
            echo "   Looked for: .venv/  venv/  env/"
            echo "💡 Create one:  jwpy_venv-create .venv"
        fi
        return 1
    fi

    # shellcheck disable=SC1090,SC1091  # path resolved at runtime; file is venv-generated
    source "$vdir/bin/activate"
    echo "✅ Activated: ${VIRTUAL_ENV:-$vdir}"
    __jwpy_kv__ "Python:" "$(command -v python) ($(python --version 2>&1))"
}


jwpy_venv-deactivate() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_venv-deactivate"
            echo "Deactivates the active virtualenv in the current shell."
            echo
            return 0
            ;;
    esac

    if [ -z "${VIRTUAL_ENV:-}" ]; then
        echo "ℹ️  No active virtual environment."
        return 1
    fi

    local prev="$VIRTUAL_ENV"
    if command -v deactivate >/dev/null 2>&1; then
        deactivate
    else
        # VIRTUAL_ENV inherited without the activate function (e.g. into a fresh
        # shell): undo by hand. Strip "$prev/bin" from PATH with pure parameter
        # expansion — no external tools (this path may run with a degraded PATH)
        # and no `for x in $PATH` (zsh would not word-split the scalar).
        local newpath="" rest="$PATH" seg
        while [ -n "$rest" ]; do
            seg=${rest%%:*}
            if [ "$rest" = "$seg" ]; then rest=""; else rest=${rest#*:}; fi
            if [ "$seg" = "$prev/bin" ] || [ -z "$seg" ]; then continue; fi
            if [ -z "$newpath" ]; then newpath="$seg"; else newpath="$newpath:$seg"; fi
        done
        export PATH="$newpath"
        unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT
        hash -r 2>/dev/null
    fi
    echo "✅ Deactivated: $prev"
}


jwpy_venv-remove() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwpy_venv-remove <name|path>"
        echo "Examples:"
        echo "  jwpy_venv-remove .venv"
        echo "  jwpy_venv-remove ../old-project/venv"
        echo
        echo "Refuses anything that isn't a virtualenv, and won't remove the"
        echo "currently-active one (deactivate first)."
        echo
        [ $# -eq 0 ] && return 1
        return 0
    fi

    local target="$1"
    if [ ! -d "$target" ]; then
        echo "❌ '$target' is not a directory."
        return 1
    fi
    if [ ! -f "$target/pyvenv.cfg" ] && [ ! -f "$target/bin/activate" ]; then
        echo "❌ '$target' doesn't look like a virtualenv (no pyvenv.cfg / bin/activate)."
        echo "   Refusing to delete it."
        return 1
    fi

    # never delete the active venv out from under the shell
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        local rp_t rp_v
        rp_t=$(cd "$target" 2>/dev/null && pwd)
        rp_v=$(cd "$VIRTUAL_ENV" 2>/dev/null && pwd)
        if [ -n "$rp_t" ] && [ "$rp_t" = "$rp_v" ]; then
            echo "⚠️  '$target' is the ACTIVE virtualenv — run jwpy_venv-deactivate first."
            return 1
        fi
    fi

    echo "🔴 This will permanently delete this virtualenv:"
    __jwpy_kv__ "Location:" "$target"
    [ -x "$target/bin/python" ] && __jwpy_kv__ "Python:" "$("$target/bin/python" --version 2>&1)"
    echo -n "Are you sure? [y/N] "
    local reply
    read -r reply
    case "$reply" in
        y|Y) ;;
        *)   echo "Operation cancelled."; return 1 ;;
    esac

    if rm -rf "$target"; then
        echo "✅ Removed '$target'"
    else
        echo "❌ Failed to remove '$target'"
        return 1
    fi
}


jwpy_venv-list() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_venv-list"
            echo "Lists virtualenvs found under the current directory (depth ≤ 2)."
            echo
            return 0
            ;;
    esac

    echo "🐍 Virtual environments under $(pwd)"
    local cfg vdir name ver rp marker n=0
    while IFS= read -r cfg; do
        vdir=${cfg%/pyvenv.cfg}
        vdir=${vdir#./}
        name=$vdir
        ver="?"
        [ -x "$vdir/bin/python" ] && ver=$("$vdir/bin/python" --version 2>&1)
        marker="  "
        rp=$(cd "$vdir" 2>/dev/null && pwd)
        [ -n "$rp" ] && [ "$rp" = "${VIRTUAL_ENV:-}" ] && marker=" *"
        printf "  %s %-22s %s\n" "$marker" "$name" "$ver"
        n=$((n + 1))
    done < <(find . -maxdepth 2 -name pyvenv.cfg -type f 2>/dev/null | sort)

    if [ "$n" -eq 0 ]; then
        echo "  (none found)"
        echo "💡 Create one:  jwpy_venv-create .venv"
    else
        echo
        echo "  ( * = active )"
    fi
}


jwpy_venv-info() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_venv-info [name|path]"
            echo "Shows the active venv, or the named / auto-discovered one."
            echo
            return 0
            ;;
    esac

    local vdir="" active="no" py pipver n
    if [ -n "${VIRTUAL_ENV:-}" ] && [ -z "${1:-}" ]; then
        vdir="$VIRTUAL_ENV"
        active="yes"
    elif vdir=$(__jwpy_venv_find__ "${1:-}"); then
        [ "$vdir" = "${VIRTUAL_ENV:-}" ] && active="yes"
    else
        if [ -n "${1:-}" ]; then
            echo "❌ No venv found at '$1'"
        else
            echo "ℹ️  No active venv and none found in $(pwd) (.venv/  venv/  env/)"
            echo "💡 Create one:  jwpy_venv-create .venv"
        fi
        return 1
    fi

    py="$vdir/bin/python"
    [ -x "$py" ] || py="$vdir/bin/python3"

    echo "🐍 Virtual environment"
    __jwpy_kv__ "Location:" "$vdir"
    __jwpy_kv__ "Active:" "$active"
    if [ -x "$py" ]; then
        __jwpy_kv__ "Python:" "$("$py" --version 2>&1)"
        __jwpy_kv__ "Interpreter:" "$py"
        pipver=$("$py" -m pip --version 2>/dev/null | awk '{print $2}')
        __jwpy_kv__ "Pip:" "${pipver:-n/a}"
        n=$("$py" -m pip list --format=freeze 2>/dev/null | grep -c '==')
        __jwpy_kv__ "Packages:" "$n"
    else
        echo "⚠️  interpreter not found under $vdir/bin"
    fi
    echo
}


# ---------------------------------------------------------------------------------
# package management (pip)
# ---------------------------------------------------------------------------------

jwpy_install() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwpy_install <package> [package...] [pip-options]"
        echo "Examples:"
        echo "  jwpy_install requests"
        echo "  jwpy_install 'django>=5' pytest"
        echo "  jwpy_install -r requirements.txt"
        echo
        echo "Targets the active venv (uv also auto-discovers ./.venv); warns"
        echo "before touching the system Python."
        echo
        [ $# -eq 0 ] && return 1
        return 0
    fi

    __jwpy_kv__ "Target:" "$(__jwpy_target__)"
    __jwpy_guard_venv__ || return 1

    echo "📦 Installing: $*"
    if __jwpy_pip__ install "$@"; then
        echo "✅ Done.  💡 jwpy_list to see what's installed."
    else
        echo "❌ install failed"
        return 1
    fi
}


jwpy_upgrade() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwpy_upgrade <package>... | --all"
        echo "Examples:"
        echo "  jwpy_upgrade pip"
        echo "  jwpy_upgrade requests urllib3"
        echo "  jwpy_upgrade --all          # upgrade every outdated package"
        echo
        [ $# -eq 0 ] && return 1
        return 0
    fi

    __jwpy_kv__ "Target:" "$(__jwpy_target__)"
    __jwpy_guard_venv__ || return 1

    if [ "$1" = "--all" ]; then
        local json line
        local pkgs=()
        # `--outdated` is incompatible with `--format=freeze`; json works on both
        # uv and pip. An empty result here means the listing FAILED (e.g. no index)
        # — surface it instead of silently reporting "up to date".
        json=$(__jwpy_pip__ list --outdated --format=json 2>/dev/null)
        if [ -z "$json" ]; then
            echo "⚠️  Could not list outdated packages (is the package index reachable?)."
            return 1
        fi
        # Extract name fields; tolerate uv ("name":"x") and pip ("name": "x") spacing.
        while IFS= read -r line; do
            [ -n "$line" ] && pkgs+=("$line")
        done < <(printf '%s\n' "$json" | grep -oE '"name": ?"[^"]*"' | cut -d'"' -f4)
        if [ "${#pkgs[@]}" -eq 0 ]; then
            echo "✅ Everything is up to date."
            return 0
        fi
        echo "⬆️  Upgrading ${#pkgs[@]} package(s): ${pkgs[*]}"
        __jwpy_pip__ install --upgrade "${pkgs[@]}"
    else
        echo "⬆️  Upgrading: $*"
        __jwpy_pip__ install --upgrade "$@"
    fi
}


jwpy_uninstall() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwpy_uninstall <package> [package...]"
        echo "Examples:"
        echo "  jwpy_uninstall requests"
        echo "  jwpy_uninstall pytest coverage"
        echo
        [ $# -eq 0 ] && return 1
        return 0
    fi

    __jwpy_kv__ "Target:" "$(__jwpy_target__)"
    __jwpy_guard_venv__ || return 1

    echo "🔴 This will uninstall: $*"
    echo -n "Are you sure? [y/N] "
    local reply
    read -r reply
    case "$reply" in
        y|Y) ;;
        *)   echo "Operation cancelled."; return 1 ;;
    esac

    # uv pip uninstall does not prompt; python -m pip needs -y to match.
    if command -v uv >/dev/null 2>&1; then
        uv pip uninstall "$@"
    else
        python -m pip uninstall -y "$@"
    fi
}


jwpy_list() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_list [pip-list-options]"
            echo "Examples:"
            echo "  jwpy_list"
            echo "  jwpy_list --format=freeze"
            echo "  jwpy_list --editable"
            echo
            return 0
            ;;
    esac

    echo "📦 Installed packages — $(__jwpy_target__)"
    __jwpy_pip__ list "$@"
}


jwpy_outdated() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_outdated [pip-list-options]"
            echo "Lists packages with newer releases available (queries the index)."
            echo
            return 0
            ;;
    esac

    echo "📦 Outdated packages — $(__jwpy_target__)"
    __jwpy_pip__ list --outdated "$@"
}


jwpy_show() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwpy_show <package> [package...]"
        echo "Examples:"
        echo "  jwpy_show requests"
        echo
        [ $# -eq 0 ] && return 1
        return 0
    fi

    __jwpy_pip__ show "$@"
}


# ---------------------------------------------------------------------------------
# dependency management
# ---------------------------------------------------------------------------------

jwpy_freeze() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_freeze [pip-freeze-options]"
            echo "Prints installed packages in requirements (pinned) format."
            echo "Examples:"
            echo "  jwpy_freeze"
            echo "  jwpy_freeze | grep -i django"
            echo
            echo "💡 Write it to a file with: jwpy_reqs-save [file]"
            echo
            return 0
            ;;
    esac

    # No header/decoration: the output is meant to be piped or redirected as-is.
    __jwpy_pip__ freeze "$@"
}


jwpy_reqs-save() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_reqs-save [file]"
            echo "Freezes the current environment into a requirements file."
            echo "Examples:"
            echo "  jwpy_reqs-save                      # -> requirements.txt"
            echo "  jwpy_reqs-save requirements-dev.txt"
            echo
            return 0
            ;;
    esac

    local file="${1:-requirements.txt}"

    if [ -e "$file" ]; then
        echo "⚠️  '$file' already exists."
        echo -n "Overwrite? [y/N] "
        local reply
        read -r reply
        case "$reply" in
            y|Y) ;;
            *)   echo "Operation cancelled."; return 1 ;;
        esac
    fi

    local content
    content=$(__jwpy_pip__ freeze 2>/dev/null)
    if [ -z "$content" ]; then
        echo "⚠️  Nothing to freeze (no packages, or no environment resolved)."
        return 1
    fi

    printf '%s\n' "$content" > "$file"
    local n
    n=$(printf '%s\n' "$content" | grep -c .)
    echo "✅ Wrote $n package(s) from $(__jwpy_target__) to $file"
}


jwpy_reqs-install() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_reqs-install [file]"
            echo "Installs packages from a requirements file."
            echo "Examples:"
            echo "  jwpy_reqs-install                      # <- requirements.txt"
            echo "  jwpy_reqs-install requirements-dev.txt"
            echo
            return 0
            ;;
    esac

    local file="${1:-requirements.txt}"
    if [ ! -f "$file" ]; then
        echo "❌ '$file' not found."
        echo "💡 Create one with: jwpy_reqs-save"
        return 1
    fi

    __jwpy_kv__ "Target:" "$(__jwpy_target__)"
    __jwpy_guard_venv__ || return 1

    echo "📦 Installing from: $file"
    if __jwpy_pip__ install -r "$file"; then
        echo "✅ Done.  💡 jwpy_list to see what's installed."
    else
        echo "❌ install failed"
        return 1
    fi
}


# ---------------------------------------------------------------------------------
# interpreter & version info
# ---------------------------------------------------------------------------------

jwpy_version() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_version"
            echo "Shows the Python toolchain for the resolved environment"
            echo "(active venv > project .venv > system), plus pip and uv."
            echo
            return 0
            ;;
    esac

    local kind root py="" pipver=""
    IFS=$'\t' read -r kind root <<<"$(__jwpy_envroot__)"
    if [ -n "$root" ] && [ -x "$root/bin/python" ]; then
        py="$root/bin/python"
    else
        py=$(command -v python3 || command -v python)
    fi

    echo "🐍 Python toolchain"
    if [ -n "$py" ]; then
        __jwpy_kv__ "Python:" "$("$py" --version 2>&1)"
        __jwpy_kv__ "Path:" "$py"
        pipver=$("$py" -m pip --version 2>/dev/null | awk '{print $2}')
        __jwpy_kv__ "Pip:" "${pipver:-n/a}"
    else
        __jwpy_kv__ "Python:" "not found"
    fi
    if command -v uv >/dev/null 2>&1; then
        __jwpy_kv__ "uv:" "$(uv --version 2>&1 | awk '{print $2}')"
    else
        __jwpy_kv__ "uv:" "not installed"
    fi
    case "$kind" in
        active) __jwpy_kv__ "Virtualenv:" "$root (active)" ;;
        venv)   __jwpy_kv__ "Virtualenv:" "$root (not activated)" ;;
        *)      __jwpy_kv__ "Virtualenv:" "none" ;;
    esac
    echo
}


jwpy_which() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_which [tool...]"
            echo "Resolves tools the way the area does (active venv > project .venv >"
            echo "global), annotating the source. Default: python pip ruff pytest mypy uv."
            echo "pipx-managed tools (code2flow, etc.) are shown as 'global (pipx)'."
            echo "Examples:"
            echo "  jwpy_which"
            echo "  jwpy_which code2flow"
            echo
            return 0
            ;;
    esac

    local kind root tool gloc glabel srclabel w=8 t2
    local tools=()
    IFS=$'\t' read -r kind root <<<"$(__jwpy_envroot__)"
    if [ "$#" -gt 0 ]; then
        tools=("$@")
    else
        tools=(python pip ruff pytest mypy uv)
    fi

    case "$kind" in
        active) echo "🔎 Environment: $root (active venv)"; srclabel="active venv" ;;
        venv)   echo "🔎 Environment: $root (.venv, not activated)"; srclabel="venv" ;;
        *)      echo "🔎 Environment: system (no venv)"; srclabel="system" ;;
    esac

    # column width = longest tool name + ':' + a 1-space gutter (handles long names)
    for t2 in "${tools[@]}"; do [ "${#t2}" -gt "$w" ] && w=${#t2}; done
    w=$((w + 2))

    for tool in "${tools[@]}"; do
        gloc=$(command -v "$tool" 2>/dev/null)
        glabel="global"
        [ -n "$gloc" ] && __jwpy_is_pipx__ "$gloc" && glabel="global (pipx)"

        # uv / pipx manage venvs from outside — always reported globally.
        case "$tool" in
            uv|pipx)
                __jwpy_kv__ "$tool:" "${gloc:-(not found)}  ·  $glabel" "$w"
                continue
                ;;
        esac

        if [ "$kind" = active ] || [ "$kind" = venv ]; then
            if [ -x "$root/bin/$tool" ]; then
                __jwpy_kv__ "$tool:" "$root/bin/$tool  ·  $srclabel" "$w"
            elif [ "$glabel" = "global (pipx)" ]; then
                # a pipx tool is a global app by design — not "missing from the venv"
                __jwpy_kv__ "$tool:" "$gloc  ·  $glabel" "$w"
            elif [ -n "$gloc" ]; then
                __jwpy_kv__ "$tool:" "(not in venv)  ·  global: $gloc" "$w"
            else
                __jwpy_kv__ "$tool:" "(not in venv)" "$w"
            fi
        else
            __jwpy_kv__ "$tool:" "${gloc:-(not found)}  ·  $glabel" "$w"
        fi
    done
}


jwpy_pythons() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_pythons"
            echo "Surveys ALL Python interpreters on PATH (system-wide), in search order,"
            echo "with versions — e.g. to choose one for 'jwpy_venv-create --python X.Y'."
            echo "Marks the active venv, and notes the project's .venv if you're in one."
            echo "(For the single interpreter THIS env resolves to, see jwpy_version.)"
            echo
            return 0
            ;;
    esac

    # env-context line: which interpreter the area resolves HERE (only when in a venv).
    # A non-activated project .venv is NOT on PATH, so it wouldn't appear below — call
    # it out so this survey isn't mistaken for "what the area will use".
    local kind root pyver
    IFS=$'\t' read -r kind root <<<"$(__jwpy_envroot__)"
    if [ -n "$root" ] && [ -x "$root/bin/python" ]; then
        pyver=$("$root/bin/python" --version 2>&1 | awk '{print $2}')
        if [ "$kind" = active ]; then
            echo "🎯 Resolved here: $root/bin/python ($pyver) — active venv"
        else
            echo "🎯 Resolved here: $root/bin/python ($pyver) — project .venv, not activated"
        fi
        echo
    fi

    echo "🐍 Python interpreters on PATH (system-wide)"
    # `path` is a reserved (special) variable in zsh — never use it as a local.
    local rest="$PATH" dir="" bin="" ver="" seen=":" mark="" active="" n=0
    [ -n "${VIRTUAL_ENV:-}" ] && active="$VIRTUAL_ENV/bin"

    # split PATH by hand (no `for x in $PATH` — zsh would not word-split the scalar)
    while [ -n "$rest" ]; do
        dir=${rest%%:*}
        if [ "$rest" = "$dir" ]; then rest=""; else rest=${rest#*:}; fi
        [ -d "$dir" ] || continue
        # find, not a glob: an unmatched glob aborts zsh with "no matches found"
        while IFS= read -r bin; do
            [ -x "$bin" ] || continue
            case "$seen" in *":$bin:"*) continue ;; esac
            seen="$seen$bin:"
            ver=$("$bin" --version 2>&1)
            mark="  "
            [ -n "$active" ] && [ "$dir" = "$active" ] && mark=" *"
            printf "  %s %-22s %s\n" "$mark" "$bin" "$ver"
            n=$((n + 1))
        done < <(find "$dir" -maxdepth 1 \( -name 'python' -o -name 'python3' -o -name 'python3.[0-9]' -o -name 'python3.[0-9][0-9]' \) 2>/dev/null | sort)
    done

    if [ "$n" -eq 0 ]; then
        echo "  (none found)"
    else
        [ -n "$active" ] && { echo; echo "  ( * = active venv )"; }
    fi
}


# ---------------------------------------------------------------------------------
# code quality
# ---------------------------------------------------------------------------------

jwpy_test() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_test [pytest-args]"
            echo "Runs the test suite with pytest (resolved venv-first)."
            echo "Examples:"
            echo "  jwpy_test"
            echo "  jwpy_test tests/ -k auth -v"
            echo
            echo "No unittest fallback on purpose: unittest can't collect pytest-style"
            echo "tests (bare test_* fns, fixtures, raises/mark), so substituting it would"
            echo "silently run nothing. If pytest isn't in the venv, install it there."
            echo
            return 0
            ;;
    esac

    local res src tool
    res=$(__jwpy_tool__ pytest) || return 1
    IFS=$'\t' read -r src tool <<<"$res"
    echo "🧪 pytest  ·  $src"
    "$tool" "$@"
}


jwpy_lint() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_lint [path...] [ruff-options]"
            echo "Lints with ruff (ruff check). Default path: current directory."
            echo "Examples:"
            echo "  jwpy_lint"
            echo "  jwpy_lint src/"
            echo
            return 0
            ;;
    esac

    __jwpy_has_path__ "$@" || set -- "$@" "."

    local res src tool
    res=$(__jwpy_tool__ ruff) || return 1
    IFS=$'\t' read -r src tool <<<"$res"
    echo "🔎 ruff check  ·  $src"
    "$tool" check "$@"
}


jwpy_typecheck() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_typecheck [path...] [mypy-options]"
            echo "Type-checks with mypy. Default path: current directory."
            echo "Examples:"
            echo "  jwpy_typecheck"
            echo "  jwpy_typecheck src/"
            echo
            return 0
            ;;
    esac

    # Default to "." only when no path was given; remember that so we can apply a
    # sensible venv/cache exclude to mypy (which, unlike ruff, would otherwise
    # descend into .venv). Explicit paths are trusted as-is.
    local defaulted=0
    if ! __jwpy_has_path__ "$@"; then
        defaulted=1
        set -- "$@" "."
    fi

    local res src tool
    res=$(__jwpy_tool__ mypy) || return 1
    IFS=$'\t' read -r src tool <<<"$res"
    echo "🔬 mypy  ·  $src"
    if [ "$defaulted" -eq 1 ]; then
        "$tool" --exclude '(^|/)(\.venv|venv|env|__pycache__|build|dist)(/|$)' "$@"
    else
        "$tool" "$@"
    fi
}


jwpy_format() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_format [--check] [path...]"
            echo "Formats code with ruff (ruff format). Default path: current directory."
            echo "Examples:"
            echo "  jwpy_format"
            echo "  jwpy_format src/"
            echo "  jwpy_format --check        # report only, don't modify (read-only)"
            echo
            return 0
            ;;
    esac

    __jwpy_has_path__ "$@" || set -- "$@" "."

    local res src tool
    res=$(__jwpy_tool__ ruff) || return 1
    IFS=$'\t' read -r src tool <<<"$res"
    echo "🎨 ruff format  ·  $src"
    "$tool" format "$@"
}


# ---------------------------------------------------------------------------------
# pipx global tools
# ---------------------------------------------------------------------------------
# The GLOBAL lane: standalone CLI apps (code2flow, pydeps, hatch, …) installed once,
# each in its own isolated venv via pipx — NOT tied to a project venv. These are thin
# pipx wrappers for *managing* those apps; running one is just typing its name, so it
# isn't a jwpy concern. (Project dev tools — ruff/pytest/mypy — are the OTHER lane,
# resolved venv-first by jwpy_test/lint/typecheck/format.) All four degrade gracefully
# when pipx is absent, via __jwpy_pipx__.

jwpy_pipx-install() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwpy_pipx-install <package> [package...] [pipx-options]"
        echo "Examples:"
        echo "  jwpy_pipx-install pydeps"
        echo "  jwpy_pipx-install code2flow pyan3"
        echo "  jwpy_pipx-install pylint --python 3.12"
        echo
        echo "Globally installs CLI apps via pipx, each in its own isolated venv."
        echo "💡 jwpy_pipx-list to see what's installed."
        echo
        [ $# -eq 0 ] && return 1
        return 0
    fi

    __jwpy_pipx__ || return 1

    echo "📦 Installing (pipx, global): $*"
    if pipx install "$@"; then
        echo "✅ Done.  💡 jwpy_pipx-list to see installed tools."
    else
        echo "❌ install failed"
        return 1
    fi
}


jwpy_pipx-upgrade() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwpy_pipx-upgrade <package>... | --all"
        echo "Examples:"
        echo "  jwpy_pipx-upgrade pylint"
        echo "  jwpy_pipx-upgrade pydeps code2flow"
        echo "  jwpy_pipx-upgrade --all          # upgrade every pipx tool"
        echo
        echo "pipx upgrades one package per call, so multiple names are upgraded in"
        echo "turn. For per-tool pipx flags (--pip-args, …), call pipx directly."
        echo
        [ $# -eq 0 ] && return 1
        return 0
    fi

    __jwpy_pipx__ || return 1

    if [ "$1" = "--all" ]; then
        echo "⬆️  Upgrading ALL pipx tools..."
        pipx upgrade-all
        return
    fi

    # pipx upgrade takes a single package; loop so multiple names work.
    local p rc=0
    for p in "$@"; do
        echo "⬆️  Upgrading: $p"
        pipx upgrade "$p" || rc=1
    done
    return "$rc"
}


jwpy_pipx-uninstall() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwpy_pipx-uninstall <package> [package...]"
        echo "Examples:"
        echo "  jwpy_pipx-uninstall pyan3"
        echo "  jwpy_pipx-uninstall code2flow pydeps"
        echo
        [ $# -eq 0 ] && return 1
        return 0
    fi

    __jwpy_pipx__ || return 1

    echo "🔴 This will uninstall these pipx tools: $*"
    echo -n "Are you sure? [y/N] "
    local reply
    read -r reply
    case "$reply" in
        y|Y) ;;
        *)   echo "Operation cancelled."; return 1 ;;
    esac

    # pipx uninstall takes a single package; loop so multiple names work.
    local p rc=0
    for p in "$@"; do
        echo "🗑️  Uninstalling: $p"
        pipx uninstall "$p" || rc=1
    done
    return "$rc"
}


jwpy_pipx-list() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwpy_pipx-list [--short|--json|--include-injected]"
            echo "Lists global CLI apps installed with pipx (and the apps each exposes)."
            echo "Examples:"
            echo "  jwpy_pipx-list"
            echo "  jwpy_pipx-list --short        # just package version"
            echo
            return 0
            ;;
    esac

    __jwpy_pipx__ || return 1

    echo "📦 pipx global tools"

    # The default long listing opens with a 3-line "venvs / apps / man" header whose
    # paths read better column-aligned. pipx styles its output (bold) ONLY when its
    # stdout is a tty (colors.py: PRINT_COLOR = sys.stdout.isatty(); no env override),
    # so to realign while keeping that bold we run it under a pty (`script`) and
    # reformat the header in awk. Plain passthrough otherwise: with flags (--short/
    # --json carry no such header), into a non-tty (don't inject codes into a pipe or
    # file), or when `script` is unavailable.
    if [ "$#" -ne 0 ] || [ ! -t 1 ] || ! command -v script >/dev/null 2>&1; then
        pipx list "$@"
        return
    fi

    script -qec 'pipx list --skip-maintenance' /dev/null 2>/dev/null | __jwpy_pipx_list_align__
}
