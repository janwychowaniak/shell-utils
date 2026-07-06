# shellcheck shell=bash

# ---------------------------------------------------------------------------------
# table of contents
# ---------------------------------------------------------------------------------
#
# Oversight-first area — the cockpit for the live runtime: quick tools that answer
# "what is running, what is listening, what is it costing?". Everything here is 🟢
# read-only — it only queries the running system (ps / ss / free), never signals,
# kills, or reconfigures anything. Server-safe: base-Linux tools only, no daemons
# to install, no credentials. Scoped to the CURRENT USER: these are shell
# functions, so there is no `sudo jwps_*` path (sudo runs a command, not a
# function) — privileged-only detail (e.g. another user's socket owner) is reported
# as unavailable rather than faked. Want a root-powered view? Source the file for
# root separately. Mutators (kill, service start/stop) will land later behind the
# show-it-first guard; the read-only oversight layer comes first.
#
# Built incrementally (greenfield). jwps_toc() is the live index.

# One TOC row: blast-radius marker, padded function name, one-line "soul" tagline.
# printf is byte-width (identical bash/zsh); the marker sits in a fixed slot on
# every row, so the tagline column aligns regardless of emoji width.
__jwps_toc_row__() {
    printf " - %s %-17s%s\n" "$1" "$2" "$3"
}

jwps_toc() {
    echo
    echo "   blast radius:  🟢 read-only   🔵 creates   ⚪ state change / transfer   🔴 destructive"
    echo "   (oversight-first: every tool here is 🟢 read-only — it queries, never signals)"
    echo
    echo " -----------------------------  processes"
    __jwps_toc_row__ 🟢 jwps_find "cmd match, busiest first"
    __jwps_toc_row__ 🟢 jwps_tree "process tree (pstree)"
    echo
    echo " -----------------------------  ports / sockets"
    __jwps_toc_row__ 🟢 jwps_ports   "listening ports + program"
    __jwps_toc_row__ 🟢 jwps_of-port "reverse: who owns a port"
    echo
    echo " -----------------------------  resources (snapshot)"
    __jwps_toc_row__ 🟢 jwps_top   "one-shot top (cpu/mem)"
    echo
}


# ---------------------------------------------------------------------------------
# internal helpers
# ---------------------------------------------------------------------------------

# Column-align "Label  value" rows in grouped info blocks. Optional 3rd arg
# overrides the column width (default 9). Labels ASCII (printf is byte-width).
__jwps_kv__() {
    printf "%-${3:-9}s%s\n" "$1" "$2"
}

# Emit the PID chain of the CALLER's own shell — from $$ up to PID 1, one per
# line — by walking /proc/<pid>/stat's ppid field. jwps_find subtracts this set
# from its matches so an `sh -c "jwps_find <pat>"` invocation (agent-style) never
# reports the very shell that launched it: matching against the full command line
# would otherwise hit the launching `sh -c ...<pat>...` (and its `timeout`/wrapper
# parents), which all carry <pat> in their own argv. The stat comm field can hold
# spaces/parens, so parse by stripping through the last ')' first, then take
# state/ppid from the remainder.
__jwps_ancestry__() {
    local pid=$$ line rest ppid
    while [ "${pid:-0}" -gt 1 ] 2>/dev/null; do
        printf '%s\n' "$pid"
        line=$(cat "/proc/$pid/stat" 2>/dev/null) || break
        rest=${line##*") "}
        read -r _ ppid _ <<< "$rest"
        pid=$ppid
    done
}

# A section header "---[ Title ]---", rendered bold + yellow via jw_colors.sh's
# jwpaintfg* helpers when that file is sourced; plain otherwise — so
# jw_functions__ps.sh works sourced standalone (no raw ANSI here, no hard
# dependency on jw_colors.sh).
__jwps_h__() {
    if command -v jwpaintfgBold >/dev/null 2>&1 && command -v jwpaintfgYellow >/dev/null 2>&1; then
        jwpaintfgBold "$(jwpaintfgYellow "---[ $1 ]---")"
    else
        echo "---[ $1 ]---"
    fi
}

# Render `ss -tulpn` (plus any filter args) as an aligned proto/addr/port/program
# table, port-sorted — the shared engine of jwps_ports and jwps_of-port. awk pulls
# the name(pid) pairs out of ss's verbose users:((...)) field; column -t aligns.
# Returns 1 and prints nothing (not even a header) for an empty set, so each caller
# owns its own "empty" message.
__jwps_ss_table__() {
    local tab; tab=$(printf '\t')
    local body
    body=$(ss -tulpnH "$@" 2>/dev/null | awk '
        {
            proto = $1; local = $5; proc = $7
            port = local; sub(/.*:/, "", port)        # after the last colon
            addr = local; sub(/:[^:]*$/, "", addr)    # everything before it
            out = ""
            while (match(proc, /"[^"]+",pid=[0-9]+/)) {
                seg  = substr(proc, RSTART, RLENGTH)
                proc = substr(proc, RSTART + RLENGTH)
                name = seg; sub(/",pid=[0-9]+/, "", name); sub(/^"/, "", name)
                pid  = seg; sub(/.*pid=/, "", pid)
                out = out (out == "" ? "" : ",") name "(" pid ")"
            }
            if (out == "") out = "-"
            printf "%s\t%s\t%s\t%s\n", proto, addr, port, out
        }' | sort -t"$tab" -k3 -n)
    [ -z "$body" ] && return 1
    { printf 'PROTO\tADDRESS\tPORT\tPROGRAM\n'; printf '%s\n' "$body"; } | column -t -s "$tab"
}

# Emit the PIDs whose COMMAND matches <pattern> (case-insensitive ERE), one per
# line — the PID-only counterpart to jwps_find, for feeding pstree (and, later, a
# guarded kill). Same self-match defense as jwps_find, and nothing more: match the
# COMMAND column only, drop the caller's ancestry, pass the pattern via the
# environment (never awk's argv). Deliberately NO process-group exclusion — that
# would hide a real target spawned as a sibling in the caller's own group (e.g. an
# agent's `sh -c "svc & jwps_tree svc"`). Instead, callers MUST consume this with a
# `> file` redirect, NEVER a command substitution: a `$()` subshell persists during
# the ps snapshot carrying the caller's argv, so under `sh -c "...<pat>..."` it
# would self-match; a `> file` runs in the caller's own shell, so no such
# pattern-carrying subshell exists (mirrors why jwps_find streams instead of captures).
__jwps_match_pids__() {
    local excl; excl=$(__jwps_ancestry__ | tr '\n' ' ')
    JWPS_PAT="$1" ps -eo pid,args 2>/dev/null \
      | JWPS_PAT="$1" awk -v excl="$excl" '
          BEGIN {
              pat = tolower(ENVIRON["JWPS_PAT"])
              n = split(excl, A, " "); for (i = 1; i <= n; i++) X[A[i]] = 1
          }
          NR == 1 { next }
          ($1 in X) { next }                                 # our own ancestry
          {
              cmd = ""
              for (i = 2; i <= NF; i++) cmd = cmd " " $i      # the COMMAND column only
              if (tolower(cmd) ~ pat) print $1
          }'
}


# ---------------------------------------------------------------------------------
# processes
# ---------------------------------------------------------------------------------

# List running processes whose command line matches a pattern, busiest-CPU first
# — the "which process is that?" glance. One atomic `ps` snapshot piped to awk
# (no pgrep→re-ps two-step, so no dead-PID race): awk matches the pattern against
# the COMMAND column only (case-insensitive extended regex, so the numeric columns
# never false-match) and drops the caller's own ancestry. The pattern reaches awk
# via the environment — never awk's argv — and the pipe streams straight to stdout
# (no capturing subshell), so none of the helper processes here carry the pattern
# in their command line to self-match. Reports only — never signals.
jwps_find() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwps_find <pattern>"
        echo "  List running processes whose command line matches <pattern>"
        echo "  (case-insensitive extended regex), busiest-CPU first. Columns:"
        echo "  PID, PPID, USER, %CPU, %MEM, ELAPSED, COMMAND. Reports only."
        echo "Examples:"
        echo "  jwps_find python"
        echo "  jwps_find 'ssh.*-L'"
        echo "  jwps_find dockerd"
        [ $# -eq 0 ] && return 1 || return 0
    fi
    local excl; excl=$(__jwps_ancestry__ | tr '\n' ' ')   # caller's own shell chain
    JWPS_PAT="$1" ps -eo pid,ppid,user:16,pcpu,pmem,etime,args --sort=-pcpu 2>/dev/null \
      | JWPS_PAT="$1" awk -v excl="$excl" '
          BEGIN {
              pat = tolower(ENVIRON["JWPS_PAT"])
              n = split(excl, A, " "); for (i = 1; i <= n; i++) X[A[i]] = 1
          }
          NR == 1 { hdr = $0; next }
          ($1 in X) { next }                                 # our own ancestry
          {
              cmd = ""
              for (i = 7; i <= NF; i++) cmd = cmd " " $i      # the COMMAND column only
              if (tolower(cmd) ~ pat) rows[++r] = $0
          }
          END {
              if (r == 0) { print "(no processes match: " ENVIRON["JWPS_PAT"] ")"; exit }
              print hdr
              for (i = 1; i <= r; i++) print rows[i]
          }'
}

# Process tree — the "who spawned what" view. pstree(1) when present (rich, with
# PIDs); a `ps --forest` fallback otherwise. No arg → the whole system tree; a
# numeric [pid] → that process with its parents and children; a [pattern] → the
# same slice for every process whose command matches (case-insensitive), so you
# see where each one sits. Reports only.
jwps_tree() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwps_tree [pid | pattern]"
            echo "  Process tree — pstree(1), or a 'ps --forest' fallback:"
            echo "    (no arg)   the whole system tree, with PIDs"
            echo "    <pid>      that process with its parents and children"
            echo "    <pattern>  the same slice for each process matching by command"
            echo "  Reports only."
            echo "Examples:"
            echo "  jwps_tree"
            echo "  jwps_tree 1"
            echo "  jwps_tree sshd"
            return 0 ;;
    esac
    local arg="${1:-}"
    if ! command -v pstree >/dev/null 2>&1; then
        [ -n "$arg" ] && echo "💡 install 'pstree' (psmisc) for [pid]/[pattern] filtering; showing full tree" >&2
        ps -e --forest -o pid,user:16,stat,comm 2>/dev/null
        return 0
    fi
    if [ -z "$arg" ]; then
        pstree -p
        return 0
    fi
    case "$arg" in
        *[!0-9]*) ;;                                          # non-numeric → pattern, below
        *)
            if [ -d "/proc/$arg" ]; then
                pstree -sp "$arg"
            else
                echo "❌ no such PID: $arg" >&2
                return 1
            fi
            return 0 ;;
    esac
    local pids_file p
    pids_file=$(mktemp) || { echo "❌ cannot mktemp" >&2; return 1; }
    __jwps_match_pids__ "$arg" > "$pids_file"          # '> file', never $() — see helper
    if [ ! -s "$pids_file" ]; then
        rm -f "$pids_file"
        echo "(no processes match: $arg)"
        return 0
    fi
    while IFS= read -r p; do
        [ -n "$p" ] && pstree -sp "$p"
    done < "$pids_file"
    rm -f "$pids_file"
}


# ---------------------------------------------------------------------------------
# ports / sockets
# ---------------------------------------------------------------------------------

# Every LISTENING TCP/UDP socket and the process that owns it, port-sorted:
# proto, bind address, port, program(pid) — rendered by __jwps_ss_table__. Falls
# back to raw netstat where ss is absent. Reports only. Owners of OTHER users'
# sockets show only to root; a hint flags this when you are not root.
jwps_ports() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwps_ports"
            echo "  List every LISTENING TCP/UDP socket and the process that owns it"
            echo "  (proto, bind address, port, program(pid)), port-sorted. Reports only."
            echo "  Runs as the current user; owners of OTHER users' sockets show only to root."
            echo "Examples:"
            echo "  jwps_ports"
            return 0 ;;
    esac
    if ! command -v ss >/dev/null 2>&1; then
        if command -v netstat >/dev/null 2>&1; then
            echo "⚠️  ss not found — raw netstat -tulpn fallback:" >&2
            netstat -tulpn 2>/dev/null
            return 0
        fi
        echo "❌ neither ss nor netstat available" >&2
        return 1
    fi
    if ! __jwps_ss_table__; then
        echo "(no listening sockets)"
        return 0
    fi
    if [ "$(id -u)" -ne 0 ]; then
        echo
        echo "💡 not root — a '-' owner is a socket owned by another user (hidden from you)"
    fi
}

# Reverse of jwps_ports: which process is LISTENING on ONE <port> (proto, bind
# address, program(pid)) — via ss's port filter, same table renderer. Raw netstat
# fallback where ss is absent. Reports only; another user's socket owner shows only to root.
jwps_of-port() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwps_of-port <port>"
        echo "  Which process is LISTENING on <port> — the reverse of jwps_ports"
        echo "  (proto, bind address, program(pid)). Reports only; the owner shows"
        echo "  only to root if the socket belongs to another user."
        echo "Examples:"
        echo "  jwps_of-port 8080"
        echo "  jwps_of-port 443"
        [ $# -eq 0 ] && return 1 || return 0
    fi
    local port="$1"
    case "$port" in
        ''|*[!0-9]*) echo "❌ port must be an integer: $port" >&2; return 1 ;;
    esac
    if ! command -v ss >/dev/null 2>&1; then
        if command -v netstat >/dev/null 2>&1; then
            echo "⚠️  ss not found — raw netstat fallback:" >&2
            netstat -tulpn 2>/dev/null | awk -v port="$port" 'NR<=2 || $4 ~ (":" port "$")'
            return 0
        fi
        echo "❌ neither ss nor netstat available" >&2
        return 1
    fi
    if ! __jwps_ss_table__ "sport = :$port"; then
        echo "(nothing listening on port $port)"
        return 0
    fi
    if [ "$(id -u)" -ne 0 ]; then
        echo
        echo "💡 not root — a '-' owner is a socket owned by another user (hidden from you)"
    fi
}


# ---------------------------------------------------------------------------------
# resources (snapshot)
# ---------------------------------------------------------------------------------

# One-shot, non-interactive snapshot of the busiest processes — a "top" you can
# pipe or log: a system summary (uptime, load, CPUs, memory, swap, process count)
# then the top-N by CPU and top-N by memory. The top-N is a bounded summary (the
# diag-style exception to the no-caps rule); [count] tunes it. Reports only.
jwps_top() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwps_top [count]"
            echo "  Non-interactive snapshot of the busiest processes (default count: 10):"
            echo "  a system summary (load, uptime, memory) plus the top CPU and top RAM"
            echo "  consumers. A one-shot 'top', safe to pipe or log. Reports only."
            echo "Examples:"
            echo "  jwps_top"
            echo "  jwps_top 5"
            return 0 ;;
    esac
    local n="${1:-10}"
    case "$n" in
        ''|*[!0-9]*) echo "❌ count must be an integer: $n" >&2; return 1 ;;
    esac
    local fmt='pid,user:16,pcpu,pmem,etime,comm'

    echo
    __jwps_h__ "System"
    __jwps_kv__ "Uptime" "$(uptime -p 2>/dev/null | sed 's/^up //')"
    __jwps_kv__ "Load"   "$(awk '{print $1", "$2", "$3}' /proc/loadavg 2>/dev/null)"
    __jwps_kv__ "CPUs"   "$(nproc 2>/dev/null)"
    __jwps_kv__ "Memory" "$(free -h 2>/dev/null | awk 'NR==2{print $3" / "$2" used  ("$7" avail)"}')"
    __jwps_kv__ "Swap"   "$(free -h 2>/dev/null | awk '$1=="Swap:"{print $3" / "$2" used"}')"
    __jwps_kv__ "Procs"  "$(ps -e --no-headers 2>/dev/null | wc -l)"

    echo
    __jwps_h__ "Top $n by CPU"
    ps -eo "$fmt" --sort=-pcpu 2>/dev/null | head -n $((n + 1))

    echo
    __jwps_h__ "Top $n by memory"
    ps -eo "$fmt" --sort=-pmem 2>/dev/null | head -n $((n + 1))
    echo
}
