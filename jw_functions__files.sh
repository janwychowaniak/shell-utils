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
#   size    : jwfiles_bigfiles   🟢  largest individual files in subtree
#             jwfiles_disk       🟢  df + inode usage for cwd's mount
#   change  : jwfiles_oldest     🟢  least-recently-modified files
#   tree    : jwfiles_tree       🟢  depth-limited tree (tree→find fallback)
#   search  : jwfiles_find       🟢  name search, case-insensitive + highlight
#             jwfiles_grep       🟢  content search (rg→grep fallback)
#             jwfiles_ext        🟢  extension inventory of the subtree
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
    echo
    echo " -----------------------------  size / disk pressure"
    __jwfiles_toc_row__ 🟢 jwfiles_size "du, sorted, human — this dir"
    echo
    echo " -----------------------------  recency / change"
    __jwfiles_toc_row__ 🟢 jwfiles_recent "newest files, subtree"
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
        | sort -t'|' -k1,1 -rn | cut -d'|' -f2- \
        | { if [ -n "$n" ]; then head -n "$n"; else cat; fi; }
}
