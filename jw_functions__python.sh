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
}


# ---------------------------------------------------------------------------------
# internal helpers
# ---------------------------------------------------------------------------------

# Column-align "Label: value" rows. 3rd arg overrides the default width.
__jwpy_kv__() {
    printf "%-${3:-14}s%s\n" "$1" "$2"
}

# Resolve a venv directory. With $1: treat it as an explicit dir/name. Without:
# auto-discover the conventional names in the cwd. Echoes the dir + returns 0 on
# success; returns 1 if nothing usable was found.
__jwpy_venv_find__() {
    local cand
    if [ -n "${1:-}" ]; then
        if [ -f "$1/bin/activate" ]; then
            printf '%s\n' "$1"
            return 0
        fi
        return 1
    fi
    for cand in .venv venv env; do
        if [ -f "$cand/bin/activate" ]; then
            printf '%s\n' "$cand"
            return 0
        fi
    done
    return 1
}

# Run pip via the chosen backend: `uv pip` (fast; auto-resolves the active venv,
# a cwd .venv, or — with none — the system Python) when uv is installed, else
# `python -m pip` against whatever interpreter is on PATH.
__jwpy_pip__() {
    if command -v uv >/dev/null 2>&1; then
        uv pip "$@"
    else
        python -m pip "$@"
    fi
}

# Describe which environment pip ops will affect (for display + the guard).
# Returns 0 when a venv will be used, 1 when it resolves to the system Python.
__jwpy_target__() {
    local vdir
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        printf '%s\n' "$VIRTUAL_ENV (active venv)"
        return 0
    fi
    if command -v uv >/dev/null 2>&1 && vdir=$(__jwpy_venv_find__); then
        printf '%s\n' "$vdir (uv auto-discovers — not activated)"
        return 0
    fi
    printf '%s\n' "SYSTEM Python"
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
        unset VIRTUAL_ENV
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
