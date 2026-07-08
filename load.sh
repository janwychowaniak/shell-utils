# shellcheck shell=bash
#
# shell-utils loader.
#
# Source this ONE file from your ~/.bashrc or ~/.zshrc (identical for both shells):
#
#     [ -f "$HOME/bin/shell-utils/load.sh" ] && . "$HOME/bin/shell-utils/load.sh"
#
# It finds its own directory and sources the area files listed below, so that
# single line never has to change again: adding or removing an area is a commit
# here, picked up on your next `git pull` — your shell rc stays untouched.

# Locate this file's own directory (bash: BASH_SOURCE; zsh and POSIX: $0).
__jw_self="${BASH_SOURCE:-$0}"
__jw_dir="$(cd "$(dirname -- "$__jw_self")" >/dev/null 2>&1 && pwd)"

if [ -n "$__jw_dir" ] && [ -d "$__jw_dir" ]; then
    # Area files, in load order. Comment a line out to skip an area.
    for __jw_f in \
        jw_aliases \
        jw_colors \
        jw_functions__docker \
        jw_functions__git \
        jw_functions__deb \
        jw_functions__python \
        jw_functions__web \
        jw_functions__fs \
        jw_functions__ps \
        jw_functions__media \
        jw_functions__mediaff \
        jw_functions__mediaim \
        jw_functions__misc
    do
        # shellcheck disable=SC1090  # dynamic path by design
        [ -f "$__jw_dir/$__jw_f.sh" ] && . "$__jw_dir/$__jw_f.sh"
    done
    unset __jw_f
fi

unset __jw_self __jw_dir
