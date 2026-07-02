# shellcheck shell=bash

# ---------------------------------------------------------------------------------
# table of contents
# ---------------------------------------------------------------------------------
#
# Oversight-first area — the read-only cockpit for the local filesystem. Where
# jwweb_* answers "what's the state of this endpoint?" without touching it,
# jwfiles_* answers "what's the state of this directory tree?" before (and after)
# you let an agent loose on it. Mutating the tree — chmod / chown / mv / rm /
# sync — is deliberately the AGENT's lane, so this file stays a place you can run
# anything blindly. perms / owners / type are READ-ONLY here by design.
#
# Built incrementally (greenfield, demand-driven). Planned next:
#   posture : jwfiles_stat       🟢  rich stat of one path
#             jwfiles_perms      🟢  odd-perms scan (world-writable, setuid, ...)
#             jwfiles_owners     🟢  ownership breakdown
#   hygiene : jwfiles_symlinks   🟢  symlinks + targets; flags broken
#             jwfiles_empty      🟢  empty files & dirs
#             jwfiles_dupes      🟢  duplicate files by hash
#             jwfiles_weirdnames 🟢  spaces / special / non-ASCII names
#   mutators (agent-overkill exceptions, pending sign-off):
#             jwfiles_backup     🔵  timestamped copy of a path (snapshot-before)
#             jwfiles_trash      ⚪  move to XDG Trash, not rm (reversible)

# One TOC row: blast-radius marker, padded function name, one-line "soul" tagline.
# printf is byte-width (identical bash/zsh); the marker sits in a fixed slot on
# every row, so the tagline column aligns regardless of emoji width.
__jwfiles_toc_row__() {
    printf " - %s %-23s%s\n" "$1" "$2" "$3"
}

jwfiles_toc() {
    echo
    echo "   blast radius:  🟢 read-only   🔵 creates   ⚪ state change / transfer   🔴 destructive"
    echo "   (oversight-first: mutating perms / owners / content is the agent's job)"
    echo
    echo " -----------------------------  orientation (the cockpit)"
    __jwfiles_toc_row__ 🟢 jwfiles_profile "one-shot dir X-ray"
    __jwfiles_toc_row__ 🟢 jwfiles_tree    "depth-limited tree view"
    echo
    echo " -----------------------------  size / disk pressure"
    __jwfiles_toc_row__ 🟢 jwfiles_size     "du, sorted, human — this dir"
    __jwfiles_toc_row__ 🟢 jwfiles_bigfiles "largest files, subtree"
    __jwfiles_toc_row__ 🟢 jwfiles_disk     "df + inodes for the mount"
    echo
    echo " -----------------------------  recency / change"
    __jwfiles_toc_row__ 🟢 jwfiles_recent "newest files, subtree"
    __jwfiles_toc_row__ 🟢 jwfiles_oldest "oldest files, subtree"
    echo
    echo " -----------------------------  search / inventory"
    __jwfiles_toc_row__ 🟢 jwfiles_find "name search, highlighted"
    __jwfiles_toc_row__ 🟢 jwfiles_grep "content search (rg→grep)"
    __jwfiles_toc_row__ 🟢 jwfiles_ext  "extension inventory + counts"
    echo
}


# ---------------------------------------------------------------------------------
# internal helpers
# ---------------------------------------------------------------------------------

# Column-align "Label  value" rows in grouped info blocks. Optional 3rd arg
# overrides the column width (default 14). Labels ASCII (printf is byte-width).
__jwfiles_kv__() {
    printf "%-${3:-14}s%s\n" "$1" "$2"
}

# One anomaly row: "Label  count  mark". The mark (✅/⚠️) sits in the TRAILING,
# unpadded slot so a ✅↔⚠️ byte-width difference never shifts the label column.
__jwfiles_flag__() {
    local n="${2:-0}" mark="✅"
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
    [ "$n" -gt 0 ] && mark="⚠️"
    printf "%-20s%-7s%s\n" "$1" "$n" "$mark"
}

# Emit the whole stream, or only its first N lines when N is a non-empty integer.
# The opt-in cap behind jwfiles_recent / _oldest / _bigfiles' [count] argument.
__jwfiles_cap__() {
    if [ -n "$1" ]; then head -n "$1"; else cat; fi
}


# ---------------------------------------------------------------------------------
# orientation (the cockpit)
# ---------------------------------------------------------------------------------

# One-shot, read-only X-ray of a directory tree. The jwweb_diag of the local FS.
# The bounded "top N" lists below are the documented diag-style exception to the
# repo's no-silent-caps rule (like jwweb_diag's "last 20") — a profile is a
# summary, not a viewer; the dedicated viewers (jwfiles_size / _recent) are uncapped.
jwfiles_profile() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwfiles_profile [dir]"
            echo "  One-shot read-only X-ray of a directory tree (default: .):"
            echo "  location, disk pressure, counts, size, biggest/newest, extensions, flags."
            echo "Examples:"
            echo "  jwfiles_profile"
            echo "  jwfiles_profile /var/log"
            return 0 ;;
    esac
    local dir="${1:-.}"
    if [ ! -d "$dir" ]; then
        echo "❌ not a directory: $dir" >&2
        return 1
    fi

    local top=8   # bounded top-N (diag-style summary exception to no-caps)

    echo
    echo "---[ Location ]---"
    local abs; abs=$(cd "$dir" 2>/dev/null && pwd)
    __jwfiles_kv__ "Path"       "${abs:-$dir}"
    __jwfiles_kv__ "Mount"      "$(df -P  -- "$dir" 2>/dev/null | awk 'NR==2{print $6}')"
    __jwfiles_kv__ "Filesystem" "$(df -PT -- "$dir" 2>/dev/null | awk 'NR==2{print $2" on "$1}')"

    echo
    echo "---[ Disk (holding mount) ]---"
    df -h  -- "$dir" 2>/dev/null | awk 'NR==1 || NR==2'
    echo
    df -ih -- "$dir" 2>/dev/null | awk 'NR==1 || NR==2'

    echo
    echo "---[ Counts (subtree) ]---"
    __jwfiles_kv__ "Files"      "$(find "$dir" -type f 2>/dev/null | wc -l)"
    __jwfiles_kv__ "Dirs"       "$(find "$dir" -mindepth 1 -type d 2>/dev/null | wc -l)"
    __jwfiles_kv__ "Symlinks"   "$(find "$dir" -mindepth 1 -type l 2>/dev/null | wc -l)"
    __jwfiles_kv__ "Hidden"     "$(find "$dir" -mindepth 1 -name '.*' 2>/dev/null | wc -l)"
    __jwfiles_kv__ "Total size" "$(du -sh -- "$dir" 2>/dev/null | cut -f1)"

    echo
    echo "---[ Biggest entries (top $top, depth 1) ]---"
    find "$dir" -mindepth 1 -maxdepth 1 -exec du -sh {} + 2>/dev/null | sort -rh | head -n "$top"

    echo
    echo "---[ Biggest files (top $top, subtree) ]---"
    find "$dir" -type f -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -n "$top" \
        | while IFS="$(printf '\t')" read -r sz p; do
              printf '%8s  %s\n' "$(numfmt --to=iec "$sz" 2>/dev/null || echo "${sz}B")" "$p"
          done

    echo
    echo "---[ Newest files (top $top, subtree) ]---"
    find "$dir" -type f -printf '%T@|[%TY-%Tm-%Td %TH:%TM] %p\n' 2>/dev/null \
        | sort -t'|' -k1,1 -rn | head -n "$top" | cut -d'|' -f2-

    echo
    echo "---[ Extensions (top $top by count) ]---"
    find "$dir" -type f 2>/dev/null | sed -n 's/.*\.\([^./]\{1,\}\)$/\1/p' \
        | sort | uniq -c | sort -rn | head -n "$top"

    echo
    echo "---[ Flags ]---"
    __jwfiles_flag__ "Broken symlinks"   "$(find "$dir" -xtype l 2>/dev/null | wc -l)"
    __jwfiles_flag__ "Empty files"       "$(find "$dir" -type f -empty 2>/dev/null | wc -l)"
    __jwfiles_flag__ "Empty dirs"        "$(find "$dir" -mindepth 1 -type d -empty 2>/dev/null | wc -l)"
    __jwfiles_flag__ "World-writable"    "$(find "$dir" -type f -perm -o+w 2>/dev/null | wc -l)"
    __jwfiles_flag__ "Names with spaces" "$(find "$dir" -mindepth 1 -name '* *' 2>/dev/null | wc -l)"
    echo
}


# Depth-limited directory tree. Uses tree(1) when installed; otherwise a
# find-based fallback that indents each entry by its depth below the root
# (awk, so a path with regex-special characters stays inert).
jwfiles_tree() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwfiles_tree [dir] [depth]"
            echo "  Directory tree of [dir] (default: .), limited to [depth] levels"
            echo "  (default: 2). Uses tree(1) if installed, else a find-based fallback."
            echo "Examples:"
            echo "  jwfiles_tree"
            echo "  jwfiles_tree ./src 3"
            return 0 ;;
    esac
    local dir="${1:-.}" depth="${2:-2}"
    if [ ! -d "$dir" ]; then
        echo "❌ not a directory: $dir" >&2
        return 1
    fi
    case "$depth" in
        ''|*[!0-9]*) echo "❌ depth must be an integer: $depth" >&2; return 1 ;;
    esac
    if command -v tree >/dev/null 2>&1; then
        tree -L "$depth" -- "$dir"
    else
        echo "$dir"
        find "$dir" -mindepth 1 -maxdepth "$depth" 2>/dev/null | sort \
            | awk -v base="$dir" '
                { rel = substr($0, length(base) + 2)
                  n = gsub(/\//, "/", rel)
                  ind = ""; for (i = 0; i < n; i++) ind = ind "  "
                  sub(/.*\//, "", rel)
                  print ind "  " rel }'
    fi
}


# ---------------------------------------------------------------------------------
# size / disk pressure
# ---------------------------------------------------------------------------------

# Disk usage of every top-level entry, largest-first, with the tree total.
# Uncapped viewer — shows every entry; narrow with your own `head`.
jwfiles_size() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwfiles_size [dir]"
            echo "  Disk usage of each top-level entry in [dir] (default: .),"
            echo "  human-readable, largest-first, then the whole-tree total."
            echo "Examples:"
            echo "  jwfiles_size"
            echo "  jwfiles_size ~/Downloads"
            return 0 ;;
    esac
    local dir="${1:-.}"
    if [ ! -d "$dir" ]; then
        echo "❌ not a directory: $dir" >&2
        return 1
    fi
    find "$dir" -mindepth 1 -maxdepth 1 -exec du -sh {} + 2>/dev/null | sort -rh
    echo "-------"
    du -sh -- "$dir" 2>/dev/null
}


# Largest individual FILES in the subtree, biggest-first, human-readable sizes.
# Uncapped by default (pipe to head yourself); an optional leading integer caps it.
jwfiles_bigfiles() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwfiles_bigfiles [count] [dir]"
            echo "  Individual files under [dir] (default: .), largest-first by size."
            echo "  No count → full list; a leading [count] caps it."
            echo "Examples:"
            echo "  jwfiles_bigfiles"
            echo "  jwfiles_bigfiles 20 /var"
            return 0 ;;
    esac
    local n="" dir="."
    if [ $# -ge 1 ]; then
        case "$1" in
            *[!0-9]*|'') dir="$1" ;;
            *)           n="$1"; [ $# -ge 2 ] && dir="$2" ;;
        esac
    fi
    if [ ! -d "$dir" ]; then
        echo "❌ not a directory: $dir" >&2
        return 1
    fi
    find "$dir" -type f -printf '%s\t%p\n' 2>/dev/null | sort -rn | __jwfiles_cap__ "$n" \
        | while IFS="$(printf '\t')" read -r sz p; do
              printf '%8s  %s\n' "$(numfmt --to=iec "$sz" 2>/dev/null || echo "${sz}B")" "$p"
          done
}

# Disk space + inode usage for the filesystem holding a path. The quick "am I
# about to run out of room / inodes?" glance.
jwfiles_disk() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwfiles_disk [dir]"
            echo "  Disk space and inode usage for the filesystem holding [dir] (default: .)."
            echo "Examples:"
            echo "  jwfiles_disk"
            echo "  jwfiles_disk /var/lib/docker"
            return 0 ;;
    esac
    local dir="${1:-.}"
    if [ ! -d "$dir" ]; then
        echo "❌ not a directory: $dir" >&2
        return 1
    fi
    echo "---[ Space ]---"
    df -h  -- "$dir" 2>/dev/null
    echo
    echo "---[ Inodes ]---"
    df -ih -- "$dir" 2>/dev/null
}


# ---------------------------------------------------------------------------------
# recency / change
# ---------------------------------------------------------------------------------

# Files under a tree, newest-first by mtime. Uncapped by default (pipe to head
# yourself); an optional leading integer caps the list.
jwfiles_recent() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwfiles_recent [count] [dir]"
            echo "  Files under [dir] (default: .), newest-first by mtime."
            echo "  No count → full list; a leading [count] caps it."
            echo "Examples:"
            echo "  jwfiles_recent"
            echo "  jwfiles_recent 20"
            echo "  jwfiles_recent 20 /var/log"
            return 0 ;;
    esac
    local n="" dir="."
    if [ $# -ge 1 ]; then
        case "$1" in
            *[!0-9]*|'') dir="$1" ;;            # non-numeric → it's the dir
            *)           n="$1"; [ $# -ge 2 ] && dir="$2" ;;
        esac
    fi
    if [ ! -d "$dir" ]; then
        echo "❌ not a directory: $dir" >&2
        return 1
    fi
    find "$dir" -type f -printf '%T@|[%TY-%Tm-%Td %TH:%TM] %p\n' 2>/dev/null \
        | sort -t'|' -k1,1 -rn | cut -d'|' -f2- | __jwfiles_cap__ "$n"
}


# Files under a tree, OLDEST-first by mtime — the stale/forgotten end of the
# timeline. Mirror of jwfiles_recent; uncapped by default, optional leading count.
jwfiles_oldest() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwfiles_oldest [count] [dir]"
            echo "  Files under [dir] (default: .), oldest-first by mtime."
            echo "  No count → full list; a leading [count] caps it."
            echo "Examples:"
            echo "  jwfiles_oldest"
            echo "  jwfiles_oldest 20 /var/log"
            return 0 ;;
    esac
    local n="" dir="."
    if [ $# -ge 1 ]; then
        case "$1" in
            *[!0-9]*|'') dir="$1" ;;
            *)           n="$1"; [ $# -ge 2 ] && dir="$2" ;;
        esac
    fi
    if [ ! -d "$dir" ]; then
        echo "❌ not a directory: $dir" >&2
        return 1
    fi
    find "$dir" -type f -printf '%T@|[%TY-%Tm-%Td %TH:%TM] %p\n' 2>/dev/null \
        | sort -t'|' -k1,1 -n | cut -d'|' -f2- | __jwfiles_cap__ "$n"
}


# ---------------------------------------------------------------------------------
# search / inventory
# ---------------------------------------------------------------------------------

# Case-insensitive recursive NAME search, matches highlighted. The phrase is a
# literal substring (matched by find -iname and re-highlighted with grep -F), so
# metacharacters are inert. Uncapped.
jwfiles_find() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwfiles_find <phrase> [dir]"
        echo "  Case-insensitive recursive name search under [dir] (default: .),"
        echo "  with the matched phrase highlighted. Phrase is a literal substring."
        echo "Examples:"
        echo "  jwfiles_find report"
        echo "  jwfiles_find .conf /etc"
        [ $# -eq 0 ] && return 1 || return 0
    fi
    local phrase="$1" dir="${2:-.}"
    if [ ! -d "$dir" ]; then
        echo "❌ not a directory: $dir" >&2
        return 1
    fi
    find "$dir" -iname "*$phrase*" 2>/dev/null | grep -i -F --color=always -- "$phrase"
}

# Recursive CONTENT search — ripgrep if present (fast, .gitignore-aware), else
# grep -rIn (skips binaries). Pattern passed via -e so a leading '-' is inert.
# Uncapped; a no-match exit (1) is normal, not an error.
jwfiles_grep() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwfiles_grep <pattern> [dir]"
        echo "  Recursive content search under [dir] (default: .)."
        echo "  Uses ripgrep (rg) when available, else grep -rIn."
        echo "Examples:"
        echo "  jwfiles_grep TODO"
        echo "  jwfiles_grep 'def main' ./src"
        [ $# -eq 0 ] && return 1 || return 0
    fi
    local pat="$1" dir="${2:-.}"
    if [ ! -d "$dir" ]; then
        echo "❌ not a directory: $dir" >&2
        return 1
    fi
    if command -v rg >/dev/null 2>&1; then
        rg --color=always -n -e "$pat" -- "$dir"
    else
        grep -rIn --color=always -e "$pat" -- "$dir"
    fi
}

# Extension inventory of the subtree: per-extension file counts, most-common
# first. Answers "what kinds of files live here?". Uncapped.
jwfiles_ext() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwfiles_ext [dir]"
            echo "  Inventory of file extensions under [dir] (default: .),"
            echo "  with per-extension counts, most-common first."
            echo "Examples:"
            echo "  jwfiles_ext"
            echo "  jwfiles_ext ~/Downloads"
            return 0 ;;
    esac
    local dir="${1:-.}"
    if [ ! -d "$dir" ]; then
        echo "❌ not a directory: $dir" >&2
        return 1
    fi
    find "$dir" -type f 2>/dev/null | sed -n 's/.*\.\([^./]\{1,\}\)$/\1/p' \
        | sort | uniq -c | sort -rn
}
