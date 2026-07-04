# shellcheck shell=bash

# ---------------------------------------------------------------------------------
# table of contents
# ---------------------------------------------------------------------------------
#
# Oversight-first area — the cockpit for the live runtime: quick tools that answer
# "what is running, what is listening, what is it costing?". Everything here is 🟢
# read-only — it only queries the running system (ps / ss / free), never signals,
# kills, or reconfigures anything. Server-safe: base-Linux tools only, no daemons
# to install, no credentials. Mutators (kill, service start/stop) will land later
# behind the show-it-first guard; the read-only oversight layer comes first.
#
# Built incrementally (greenfield). jwps_toc() is the live index.

# One TOC row: blast-radius marker, padded function name, one-line "soul" tagline.
# printf is byte-width (identical bash/zsh); the marker sits in a fixed slot on
# every row, so the tagline column aligns regardless of emoji width.
__jwps_toc_row__() {
    printf " - %s %-15s%s\n" "$1" "$2" "$3"
}

jwps_toc() {
    echo
    echo "   blast radius:  🟢 read-only   🔵 creates   ⚪ state change / transfer   🔴 destructive"
    echo "   (oversight-first: every tool here is 🟢 read-only — it queries, never signals)"
    echo
    echo " -----------------------------  processes"
    __jwps_toc_row__ 🟢 jwps_find  "pgrep→ps, busiest first"
    echo
    echo " -----------------------------  ports / sockets"
    __jwps_toc_row__ 🟢 jwps_ports "listening ports + program"
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
# jw_functions__process.sh works sourced standalone (no raw ANSI here, no hard
# dependency on jw_colors.sh).
__jwps_h__() {
    if command -v jwpaintfgBold >/dev/null 2>&1 && command -v jwpaintfgYellow >/dev/null 2>&1; then
        jwpaintfgBold "$(jwpaintfgYellow "---[ $1 ]---")"
    else
        echo "---[ $1 ]---"
    fi
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


# ---------------------------------------------------------------------------------
# ports / sockets
# ---------------------------------------------------------------------------------

# Every LISTENING TCP/UDP socket and the process that owns it, port-sorted:
# proto, bind address, port, program(pid). ss(-tulpn) is the source; awk pulls the
# name(pid) pairs out of ss's verbose users:((...)) field, column -t aligns. Falls
# back to raw netstat where ss is absent. Reports only. Process owners for OTHER
# users' sockets need root — a hint is printed when you are not root.
jwps_ports() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwps_ports"
            echo "  List every LISTENING TCP/UDP socket and the process that owns it"
            echo "  (proto, bind address, port, program(pid)), port-sorted. Reports only."
            echo "  Process owners for other users' sockets need root (run with sudo)."
            echo "Examples:"
            echo "  jwps_ports"
            echo "  sudo jwps_ports"
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
    local tab; tab=$(printf '\t')
    local body
    body=$(ss -tulpnH 2>/dev/null | awk '
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
    if [ -z "$body" ]; then
        echo "(no listening sockets visible)"
        [ "$(id -u)" -ne 0 ] && echo "💡 run with sudo to see all process owners"
        return 0
    fi
    { printf 'PROTO\tADDRESS\tPORT\tPROGRAM\n'; printf '%s\n' "$body"; } \
        | column -t -s "$tab"
    if [ "$(id -u)" -ne 0 ]; then
        echo
        echo "💡 process owners for other users' sockets need root (sudo jwps_ports)"
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
