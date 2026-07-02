# shellcheck shell=bash

# ---------------------------------------------------------------------------------
# table of contents
# ---------------------------------------------------------------------------------
#
# Oversight-first area — the read-only cockpit for the local filesystem: quick
# tools that answer "what's the state of this directory tree?" without changing
# anything. The whole file is 🟢 read-only — perms / owners / stat only report,
# and even jwfiles_backup just PRINTS the cp -a command for you to run. No
# delete/trash tool on purpose — it must work on headless servers (no desktop
# Trash), where deletion is plain `rm`.
#
# Built incrementally (greenfield). The map is complete — jwfiles_toc() is the
# live index.

# One TOC row: blast-radius marker, padded function name, one-line "soul" tagline.
# printf is byte-width (identical bash/zsh); the marker sits in a fixed slot on
# every row, so the tagline column aligns regardless of emoji width.
__jwfiles_toc_row__() {
    printf " - %s %-23s%s\n" "$1" "$2" "$3"
}

jwfiles_toc() {
    echo
    echo "   blast radius:  🟢 read-only   🔵 creates   ⚪ state change / transfer   🔴 destructive"
    echo "   (oversight-first — this whole area is read-only; nothing here changes state)"
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
    echo " -----------------------------  posture / attributes (read-only)"
    __jwfiles_toc_row__ 🟢 jwfiles_stat   "rich stat of one path"
    __jwfiles_toc_row__ 🟢 jwfiles_perms  "odd-perms scan (RO)"
    __jwfiles_toc_row__ 🟢 jwfiles_owners "ownership breakdown"
    echo
    echo " -----------------------------  hygiene / anomalies"
    __jwfiles_toc_row__ 🟢 jwfiles_symlinks   "symlinks + targets, broken"
    __jwfiles_toc_row__ 🟢 jwfiles_empty      "empty files & dirs"
    __jwfiles_toc_row__ 🟢 jwfiles_weirdnames "spaces/special/non-ASCII"
    echo
    echo " -----------------------------  backup (prints the command)"
    __jwfiles_toc_row__ 🟢 jwfiles_backup "prints the cp -a command"
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

# One-shot, read-only X-ray of a directory tree — the aggregate profiler of this area.
# The bounded "top N" lists below are the deliberate exception to the repo's
# no-silent-caps rule — a profile is a summary, not a viewer; the dedicated viewers
# (jwfiles_size / _recent) are uncapped.
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


# ---------------------------------------------------------------------------------
# posture / attributes (read-only — these only report, never change anything)
# ---------------------------------------------------------------------------------

# Rich, read-only metadata for one path (a single stat call, parsed field-wise):
# type, symbolic+octal perms, owner/group (names + numeric), size, hard links,
# inode, and access/modify/change times. Symlinks report the LINK itself (its
# target is shown in the header), so a broken symlink still resolves.
jwfiles_stat() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwfiles_stat <path>"
        echo "  Rich read-only metadata for one path: type, perms (symbolic + octal),"
        echo "  owner/group, size, links, inode, and access/modify/change times."
        echo "Examples:"
        echo "  jwfiles_stat ./report.pdf"
        echo "  jwfiles_stat /etc/passwd"
        [ $# -eq 0 ] && return 1 || return 0
    fi
    local p="$1"
    if [ ! -e "$p" ] && [ ! -L "$p" ]; then
        echo "❌ no such path: $p" >&2
        return 1
    fi
    local ftype perms operm owner group uid gid size links inode atime mtime ctime
    IFS='|' read -r ftype perms operm owner group uid gid size links inode atime mtime ctime \
        < <(stat -c '%F|%A|%a|%U|%G|%u|%g|%s|%h|%i|%x|%y|%z' -- "$p" 2>/dev/null)
    echo
    echo "---[ $(stat -c '%N' -- "$p" 2>/dev/null) ]---"
    __jwfiles_kv__ "Type"   "$ftype"
    __jwfiles_kv__ "Perms"  "$perms  ($operm)"
    __jwfiles_kv__ "Owner"  "$owner:$group  ($uid:$gid)"
    __jwfiles_kv__ "Size"   "$size bytes  ($(numfmt --to=iec "$size" 2>/dev/null || echo "$size"))"
    __jwfiles_kv__ "Links"  "$links"
    __jwfiles_kv__ "Inode"  "$inode"
    __jwfiles_kv__ "Access" "$atime"
    __jwfiles_kv__ "Modify" "$mtime"
    __jwfiles_kv__ "Change" "$ctime"
    echo
}

# Read-only scan for security-relevant permissions in the subtree. Reports only
# (each row: symbolic perms, owner:group, path) — it never chmods anything. Sections:
# world-writable files, world-writable dirs missing the sticky bit, setuid, setgid.
jwfiles_perms() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwfiles_perms [dir]"
            echo "  Read-only scan for risky permissions under [dir] (default: .):"
            echo "  world-writable files, world-writable dirs w/o sticky bit, setuid, setgid."
            echo "  Reports only — never changes anything."
            echo "Examples:"
            echo "  jwfiles_perms"
            echo "  jwfiles_perms /var/www"
            return 0 ;;
    esac
    local dir="${1:-.}"
    if [ ! -d "$dir" ]; then
        echo "❌ not a directory: $dir" >&2
        return 1
    fi
    echo
    echo "---[ World-writable files ]---"
    find "$dir" -type f -perm -o+w -printf '%M  %u:%g  %p\n' 2>/dev/null
    echo
    echo "---[ World-writable dirs without sticky bit ]---"
    find "$dir" -type d -perm -o+w ! -perm -1000 -printf '%M  %u:%g  %p\n' 2>/dev/null
    echo
    echo "---[ setuid ]---"
    find "$dir" -type f -perm -4000 -printf '%M  %u:%g  %p\n' 2>/dev/null
    echo
    echo "---[ setgid ]---"
    find "$dir" -type f -perm -2000 -printf '%M  %u:%g  %p\n' 2>/dev/null
    echo
}

# Ownership breakdown of the subtree: item count per user:group, most-first.
# The "whose files are these?" glance. Uncapped, read-only.
jwfiles_owners() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwfiles_owners [dir]"
            echo "  Ownership breakdown of the subtree under [dir] (default: .):"
            echo "  item count per user:group, most-first. Reports only."
            echo "Examples:"
            echo "  jwfiles_owners"
            echo "  jwfiles_owners /srv"
            return 0 ;;
    esac
    local dir="${1:-.}"
    if [ ! -d "$dir" ]; then
        echo "❌ not a directory: $dir" >&2
        return 1
    fi
    find "$dir" -printf '%u:%g\n' 2>/dev/null | sort | uniq -c | sort -rn
}


# ---------------------------------------------------------------------------------
# hygiene / anomalies
# ---------------------------------------------------------------------------------

# Every symlink in the subtree with its target, then the broken (dangling) subset
# called out separately — the actionable ones. Read-only.
jwfiles_symlinks() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwfiles_symlinks [dir]"
            echo "  List every symlink under [dir] (default: .) with its target,"
            echo "  then the broken (dangling) subset on its own."
            echo "Examples:"
            echo "  jwfiles_symlinks"
            echo "  jwfiles_symlinks /etc"
            return 0 ;;
    esac
    local dir="${1:-.}"
    if [ ! -d "$dir" ]; then
        echo "❌ not a directory: $dir" >&2
        return 1
    fi
    echo
    echo "---[ All symlinks ]---"
    find "$dir" -type l -printf '%p -> %l\n' 2>/dev/null | sort
    echo
    echo "---[ Broken (dangling) ]---"
    find "$dir" -xtype l -printf '%p -> %l\n' 2>/dev/null | sort
    echo
}

# Empty files and empty directories in the subtree — the usual `find -delete`
# clutter, listed. Read-only (listing only). Uncapped.
jwfiles_empty() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwfiles_empty [dir]"
            echo "  Zero-byte files and empty directories under [dir] (default: .)."
            echo "Examples:"
            echo "  jwfiles_empty"
            echo "  jwfiles_empty ~/Downloads"
            return 0 ;;
    esac
    local dir="${1:-.}"
    if [ ! -d "$dir" ]; then
        echo "❌ not a directory: $dir" >&2
        return 1
    fi
    echo
    echo "---[ Empty files ]---"
    find "$dir" -type f -empty 2>/dev/null | sort
    echo
    echo "---[ Empty dirs ]---"
    find "$dir" -mindepth 1 -type d -empty 2>/dev/null | sort
    echo
}

# Names that will bite later: with spaces, with shell/glob-special ASCII, or with
# non-ASCII bytes — three labeled subtree scans (grep on the path, so no fragile
# find-glob escaping). Read-only — reports only.
jwfiles_weirdnames() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwfiles_weirdnames [dir]"
            echo "  Scan the subtree under [dir] (default: .) for problematic names:"
            echo "  names with spaces, shell/glob-special characters, or non-ASCII bytes."
            echo "  Reports only."
            echo "Examples:"
            echo "  jwfiles_weirdnames"
            echo "  jwfiles_weirdnames ~/Music"
            return 0 ;;
    esac
    local dir="${1:-.}"
    if [ ! -d "$dir" ]; then
        echo "❌ not a directory: $dir" >&2
        return 1
    fi
    echo
    echo "---[ Names with spaces ]---"
    find "$dir" -mindepth 1 2>/dev/null | grep ' ' | sort
    echo
    echo "---[ Names with shell/glob-special characters ]---"
    find "$dir" -mindepth 1 2>/dev/null \
        | LC_ALL=C grep -E '[]!"#$%&'\''()*+,:;<=>?@[\\^`{|}~]' | sort
    echo
    echo "---[ Names with non-ASCII characters ]---"
    find "$dir" -mindepth 1 2>/dev/null | LC_ALL=C grep '[^ -~]' | sort
    echo
}


# ---------------------------------------------------------------------------------
# backup (prints the command — you run it)
# ---------------------------------------------------------------------------------

# 🟢 Print (do NOT run) the `cp -a` command that would snapshot each path alongside
# itself as <path>.<YYYYMMDD-HHMMSS>.JWBAK. Read-only by design: you see exactly what
# would happen and run it yourself — eyeball it, or pipe to a shell. Print-the-command,
# don't-execute is intentional; missing paths are flagged on stderr so stdout stays a
# clean, runnable command list.
jwfiles_backup() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwfiles_backup <path> [path...]"
        echo "  Print (does NOT run) the 'cp -a' command to snapshot each path as:"
        echo "    <path>.<YYYYMMDD-HHMMSS>.JWBAK"
        echo "  You inspect it, then run it yourself (or pipe:  jwfiles_backup x | sh)."
        echo "Examples:"
        echo "  jwfiles_backup ./config.yml"
        echo "  jwfiles_backup ./src ./notes.md"
        [ $# -eq 0 ] && return 1 || return 0
    fi
    local ts p dest
    ts=$(date +%Y%m%d-%H%M%S)
    for p in "$@"; do
        [ -e "$p" ] || [ -L "$p" ] || echo "⚠️  no such path (command still printed): $p" >&2
        dest="${p%/}.${ts}.JWBAK"
        printf 'cp -a -- "%s" "%s"\n' "$p" "$dest"
    done
}
