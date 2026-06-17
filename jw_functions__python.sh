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
    echo " - 🟢 jwpy_venv-info"
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
