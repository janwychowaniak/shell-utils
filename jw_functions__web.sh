# shellcheck shell=bash

# ---------------------------------------------------------------------------------
# table of contents
# ---------------------------------------------------------------------------------
#
# Diag-first, oversight-only area (HTTP / TLS / DNS / connectivity diagnostics).
# Blast-radius marker = effect on the remote ENDPOINT, not local state; HTTP
# GET/HEAD are 🟢 because they are idempotent reads. Built incrementally.
# Planned next (all 🟢):
#   HTTP   : jwweb_status              (head/get folded: headers covers HEAD, raw curl covers GET)
#   TLS    : jwweb_cert-chain          (cert-file → a --file flag on jwweb_cert)
#   DNS    : jwweb_dns-trace jwweb_dns-reverse
#   net    : jwweb_trace               (ping = zbyt cienki, by go opakowywać)
# jwweb_domain (registration) is RDAP-first with a whois fallback — supersedes
# the old "jwweb_whois" idea (RDAP returns parseable JSON; WHOIS is the fallback).

jwweb_toc() {
    echo
    echo "   blast radius:  🟢 tylko odczyt   🔵 tworzy   ⚪ zmiana stanu / transfer   🔴 kasuje (destructive)"
    echo "   (marker = skutek po stronie ENDPOINTU, nie lokalny; HTTP GET/HEAD = 🟢 idempotentne)"
    echo
    echo " -----------------------------  HTTP inspection / probing"
    echo " - 🟢 jwweb_headers"
    echo " - 🟢 jwweb_redirects"
    echo " - 🟢 jwweb_timing"
    echo " - 🟢 jwweb_json"
    echo
    echo " -----------------------------  TLS / certyfikaty"
    echo " - 🟢 jwweb_cert"
    echo " - 🟢 jwweb_cert-expiry"
    echo " - 🟢 jwweb_tls"
    echo
    echo " -----------------------------  DNS"
    echo " - 🟢 jwweb_dns"
    echo " - 🟢 jwweb_dns-prop"
    echo " - 🟢 jwweb_domain"
    echo
    echo " -----------------------------  łączność / osiągalność"
    echo " - 🟢 jwweb_port"
    echo
    echo " -----------------------------  diagnostyka zbiorcza"
    echo " - 🟢 jwweb_diag"
    echo
}


# ---------------------------------------------------------------------------------
# internal helpers
# ---------------------------------------------------------------------------------

# Column-align "Label  value" rows in grouped info/summary blocks. Optional 3rd
# arg overrides the column width (default 16) per block (cert block=12,
# diag general=14, timing=9, security headers=20).
__jwweb_kv__() {
    printf "%-${3:-16}s%s\n" "$1" "$2"
}

# Parse a URL/host into "scheme host port path" on one line. No scheme ⇒ https;
# port defaults from the scheme (443/80). Pure parameter-expansion (bash + zsh).
__jwweb_parse_url__() {
    local url="$1"
    local scheme="" rest="" hostport="" host="" port="" pth="/"
    case "$url" in
        http://*)  scheme="http";  rest="${url#http://}" ;;
        https://*) scheme="https"; rest="${url#https://}" ;;
        *)         scheme="https"; rest="$url" ;;
    esac
    # strip any userinfo (user:pass@host)
    case "$rest" in *@*) rest="${rest#*@}" ;; esac
    # split host[:port] from /path
    case "$rest" in
        */*) hostport="${rest%%/*}"; pth="/${rest#*/}" ;;
        *)   hostport="$rest";       pth="/" ;;
    esac
    case "$hostport" in
        *:*) host="${hostport%%:*}"; port="${hostport##*:}" ;;
        *)   host="$hostport" ;;
    esac
    if [ -z "$port" ]; then
        if [ "$scheme" = "http" ]; then port="80"; else port="443"; fi
    fi
    echo "$scheme $host $port $pth"
}

# Resolve a host. Echoes "RESOLVER <label>" then "A <ip>" / "AAAA <ip>" lines.
# dig → host → getent fallback (graceful degradation).
__jwweb_resolve__() {
    local host="$1"
    local a="" aaaa="" ip=""
    if command -v dig >/dev/null 2>&1; then
        a="$(dig +short A    "$host" 2>/dev/null | grep -E '^[0-9.]+$')"
        aaaa="$(dig +short AAAA "$host" 2>/dev/null | grep -E ':')"
        echo "RESOLVER system (dig)"
    elif command -v host >/dev/null 2>&1; then
        a="$(host -t A    "$host" 2>/dev/null | awk '/has address/{print $NF}')"
        aaaa="$(host -t AAAA "$host" 2>/dev/null | awk '/IPv6 address/{print $NF}')"
        echo "RESOLVER system (host)"
    elif command -v getent >/dev/null 2>&1; then
        a="$(getent ahostsv4 "$host" 2>/dev/null | awk '{print $1}' | sort -u)"
        aaaa="$(getent ahostsv6 "$host" 2>/dev/null | awk '{print $1}' | sort -u)"
        echo "RESOLVER system (getent)"
    else
        echo "RESOLVER none"
    fi
    while IFS= read -r ip; do [ -n "$ip" ] && echo "A $ip";    done <<< "$a"
    while IFS= read -r ip; do [ -n "$ip" ] && echo "AAAA $ip"; done <<< "$aaaa"
}

# One TLS handshake to host:port (SNI=arg3|host). Echoes the raw openssl
# s_client output (empty if unreachable). The single capture point both the
# cert helpers and jwweb_cert parse, so a host is hit only once per call.
__jwweb_tls_fetch__() {
    local host="$1" port="${2:-443}" sni="${3:-$1}"
    echo | openssl s_client -servername "$sni" -connect "$host:$port" 2>/dev/null
}

# Read s_client output on stdin, echo "PROTO <v>" / "CIPHER <c>". Handles both
# the "Protocol  :"/"Cipher    :" SSL-Session block and the terse
# "New, TLSv1.3, Cipher is <c>" summary (depends on the openssl build).
__jwweb_protocipher__() {
    local sout="" proto="" cipher=""
    sout="$(cat)"
    proto="$(printf '%s\n' "$sout" | grep -E 'Protocol[[:space:]]*:' | head -1 | sed 's/.*:[[:space:]]*//')"
    cipher="$(printf '%s\n' "$sout" | grep -E 'Cipher[[:space:]]*:' | head -1 | sed 's/.*:[[:space:]]*//')"
    [ -z "$proto" ]  && proto="$(printf '%s\n' "$sout" | grep -E '^New, ' | head -1 | awk -F', ' '{print $2}')"
    [ -z "$cipher" ] && cipher="$(printf '%s\n' "$sout" | grep -iE 'Cipher is ' | head -1 | sed 's/.*Cipher is //')"
    [ -n "$proto" ]  && echo "PROTO $proto"
    [ -n "$cipher" ] && echo "CIPHER $cipher"
}

# Echo the openssl x509 fields (notAfter= / subject= / issuer=) plus
# "PROTO <v>" / "CIPHER <c>" for host:port. Returns 1 if unreachable / no cert.
__jwweb_cert_enddate__() {
    local host="$1" port="${2:-443}" sni="${3:-$1}"
    local sout="" x509=""
    sout="$(__jwweb_tls_fetch__ "$host" "$port" "$sni")"
    [ -z "$sout" ] && return 1
    x509="$(printf '%s\n' "$sout" | openssl x509 -noout -enddate -subject -issuer 2>/dev/null)"
    [ -z "$x509" ] && return 1
    printf '%s\n' "$x509"
    printf '%s\n' "$sout" | __jwweb_protocipher__
}

# Extract one header's value (case-insensitive) from a header block on $1.
__jwweb_hdr_get__() {
    printf '%s\n' "$1" | grep -i "^$2:" | head -1 | sed "s/^[^:]*:[[:space:]]*//"
}

# Read a response-header block on stdin, print the security-header checklist.
__jwweb_sec_headers__() {
    local hdrs="" spec="" name="" label="" val="" pad=20
    hdrs="$(cat)"
    for spec in \
        "strict-transport-security|HSTS" \
        "content-security-policy|CSP" \
        "x-frame-options|X-Frame-Options" \
        "x-content-type-options|X-Content-Type" \
        "referrer-policy|Referrer-Policy" \
        "permissions-policy|Permissions-Policy"; do
        name="${spec%%|*}"
        label="${spec##*|}"
        val="$(__jwweb_hdr_get__ "$hdrs" "$name")"
        if [ -n "$val" ]; then
            __jwweb_kv__ "$label" "✅ $val" "$pad"
        else
            __jwweb_kv__ "$label" "❌ brak" "$pad"
        fi
    done
    # info-leak headers: presence is a ⚠️, absence is silent
    for spec in \
        "server|Server (leak)" \
        "x-powered-by|X-Powered-By"; do
        name="${spec%%|*}"
        label="${spec##*|}"
        val="$(__jwweb_hdr_get__ "$hdrs" "$name")"
        [ -n "$val" ] && __jwweb_kv__ "$label" "⚠️ $val" "$pad"
    done
    return 0
}

# (a-b)*1000 ms, clamped at 0. Empty args treated as 0.
__jwweb_ms_delta__() {
    awk -v a="$1" -v b="$2" 'BEGIN{ d=(a-b)*1000; if(d<0)d=0; printf "%d ms", d }'
}

# TCP reachability probe. Returns 0 open / 1 closed / 2 no-tool (no nc, non-bash).
# nc → bash /dev/tcp fallback (zsh lacks /dev/tcp). Prints nothing.
__jwweb_tcp_probe__() {
    local host="$1" port="$2"
    if command -v nc >/dev/null 2>&1; then
        nc -z -w 5 "$host" "$port" >/dev/null 2>&1 && return 0
        return 1
    elif [ -n "${BASH_VERSION:-}" ]; then
        (exec 3<>"/dev/tcp/$host/$port") >/dev/null 2>&1 && return 0
        return 1
    fi
    return 2
}

# Print the per-stage timing breakdown from curl's cumulative -w values.
# args: scheme t_namelookup t_connect t_appconnect t_starttransfer t_total [width]
__jwweb_print_timing__() {
    local scheme="$1" t_dns="$2" t_conn="$3" t_tls="$4" t_ttfb="$5" t_total="$6" tw="${7:-9}"
    __jwweb_kv__ "DNS"     "$(__jwweb_ms_delta__ "$t_dns"  0)"        "$tw"
    __jwweb_kv__ "Connect" "$(__jwweb_ms_delta__ "$t_conn" "$t_dns")" "$tw"
    if [ "$scheme" = "https" ]; then
        __jwweb_kv__ "TLS"  "$(__jwweb_ms_delta__ "$t_tls"  "$t_conn")" "$tw"
        __jwweb_kv__ "TTFB" "$(__jwweb_ms_delta__ "$t_ttfb" "$t_tls")"  "$tw"
    else
        __jwweb_kv__ "TTFB" "$(__jwweb_ms_delta__ "$t_ttfb" "$t_conn")" "$tw"
    fi
    __jwweb_kv__ "Total" "$(__jwweb_ms_delta__ "$t_total" 0)" "$tw"
}


# ---------------------------------------------------------------------------------
# HTTP inspection / probing
# ---------------------------------------------------------------------------------

# 🟢 Response headers + security-header audit for a URL.
jwweb_headers() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwweb_headers <url> [--all]"
        echo "Examples:"
        echo "  jwweb_headers example.com"
        echo "  jwweb_headers https://api.example.com/health"
        echo "  jwweb_headers example.com --all      # nagłówki każdego hopa redirectów"
        echo
        echo "Nagłówki odpowiedzi + audyt nagłówków bezpieczeństwa (HSTS/CSP/XFO/...)."
        [ $# -eq 0 ] && return 1 || return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        echo "❌ curl nie jest dostępny" >&2; return 1
    fi

    local url="" all=0 arg=""
    for arg in "$@"; do
        case "$arg" in
            --all)   all=1 ;;
            -*)      echo "⚠️ nieznana opcja: $arg" >&2 ;;
            *)       [ -z "$url" ] && url="$arg" ;;
        esac
    done
    [ -z "$url" ] && { echo "❌ brak URL" >&2; return 1; }
    case "$url" in http://*|https://*) ;; *) url="https://$url" ;; esac

    local raw="" code="" final=""
    raw="$(curl -sS -I -L "$url" 2>/dev/null)"
    code="$(printf '%s\n' "$raw" | grep -E '^HTTP/' | tail -1 | awk '{print $2}')"
    # some servers reject HEAD -> retry as GET, discarding the body
    case "$code" in
        405|501|"") raw="$(curl -sS -L -o /dev/null -D - "$url" 2>/dev/null)" ;;
    esac
    [ -z "$raw" ] && { echo "❌ brak odpowiedzi z $url" >&2; return 1; }
    raw="$(printf '%s\n' "$raw" | tr -d '\r')"
    # final response block = from the last "HTTP/" status line to the end
    final="$(printf '%s\n' "$raw" | awk '/^HTTP\//{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}')"

    echo
    echo "---[ Response headers: $url ]---"
    if [ "$all" -eq 1 ]; then printf '%s\n' "$raw"; else printf '%s\n' "$final"; fi
    echo
    echo "---[ Security headers ]---"
    printf '%s\n' "$final" | __jwweb_sec_headers__
    return 0
}

# 🟢 Request-timing breakdown (DNS / connect / TLS / TTFB / total) for a URL.
jwweb_timing() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwweb_timing <url>"
        echo "Examples:"
        echo "  jwweb_timing example.com"
        echo "  jwweb_timing https://api.example.com/health"
        echo
        echo "Rozbicie czasu żądania: DNS / connect / TLS / TTFB / total (curl -w)."
        [ $# -eq 0 ] && return 1 || return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        echo "❌ curl nie jest dostępny" >&2; return 1
    fi

    local url="$1"
    case "$url" in http://*|https://*) ;; *) url="https://$url" ;; esac
    local scheme="" host="" port="" pth=""
    read -r scheme host port pth <<< "$(__jwweb_parse_url__ "$url")"

    local winfo=""
    winfo="$(curl -sS -o /dev/null -L \
        -w 'CODE=%{http_code}\nT_DNS=%{time_namelookup}\nT_CONN=%{time_connect}\nT_TLS=%{time_appconnect}\nT_TTFB=%{time_starttransfer}\nT_TOTAL=%{time_total}\n' \
        "$url" 2>/dev/null)"
    [ -z "$winfo" ] && { echo "❌ brak odpowiedzi z $url" >&2; return 1; }

    local code="" hmark=""
    code="$(printf '%s\n' "$winfo" | grep '^CODE=' | cut -d= -f2)"
    case "$code" in
        2*)      hmark="✅ $code" ;;
        3*)      hmark="↪ $code" ;;
        000|"")  hmark="❌ brak odpowiedzi" ;;
        4*|5*)   hmark="❌ $code" ;;
        *)       hmark="$code" ;;
    esac

    local t_dns="" t_conn="" t_tls="" t_ttfb="" t_total=""
    t_dns="$(printf   '%s\n' "$winfo" | grep '^T_DNS='   | cut -d= -f2)"
    t_conn="$(printf  '%s\n' "$winfo" | grep '^T_CONN='  | cut -d= -f2)"
    t_tls="$(printf   '%s\n' "$winfo" | grep '^T_TLS='   | cut -d= -f2)"
    t_ttfb="$(printf  '%s\n' "$winfo" | grep '^T_TTFB='  | cut -d= -f2)"
    t_total="$(printf '%s\n' "$winfo" | grep '^T_TOTAL=' | cut -d= -f2)"

    echo
    echo "---[ Timing: $url ]---"
    __jwweb_kv__ "Status" "$hmark" 9
    __jwweb_print_timing__ "$scheme" "$t_dns" "$t_conn" "$t_tls" "$t_ttfb" "$t_total" 9
    return 0
}

# 🟢 Trace the HTTP redirect chain hop-by-hop, ending at the final URL/status.
jwweb_redirects() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwweb_redirects <url>"
        echo "Examples:"
        echo "  jwweb_redirects example.com"
        echo "  jwweb_redirects http://github.com"
        echo
        echo "Łańcuch przekierowań 3xx hop po hopie + URL/status końcowy."
        [ $# -eq 0 ] && return 1 || return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        echo "❌ curl nie jest dostępny" >&2; return 1
    fi

    local url="$1"
    case "$url" in http://*|https://*) ;; *) url="https://$url" ;; esac

    local raw="" chain=""
    raw="$(curl -sS -I -L "$url" 2>/dev/null | tr -d '\r')"
    [ -z "$raw" ] && { echo "❌ brak odpowiedzi z $url" >&2; return 1; }
    # per response block: "<code>\t<location-or-empty>"
    chain="$(printf '%s\n' "$raw" | awk '
        /^HTTP\// { if (seen) print code "\t" loc; code=$2; loc=""; seen=1 }
        tolower($0) ~ /^location:/ { loc=$2 }
        END { if (seen) print code "\t" loc }')"

    echo
    echo "---[ Redirect chain: $url ]---"
    local code="" loc="" i=0 finalcode="" finalurl="$url" hmark=""
    while IFS="$(printf '\t')" read -r code loc; do
        [ -z "$code" ] && continue
        if [ -n "$loc" ]; then
            i=$((i + 1))
            __jwweb_kv__ "Hop $i" "$code  →  $loc" 9
            finalurl="$loc"
        fi
        finalcode="$code"
    done <<< "$chain"
    case "$finalcode" in
        2*)     hmark="✅ $finalcode" ;;
        3*)     hmark="↪ $finalcode" ;;
        4*|5*)  hmark="❌ $finalcode" ;;
        *)      hmark="${finalcode:-?}" ;;
    esac
    __jwweb_kv__ "Final" "$hmark  $finalurl  ($i redirects)" 9
    echo
    return 0
}

# 🟢 GET a URL and validate + pretty-print the JSON body (jq), with status/size.
jwweb_json() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwweb_json <url>"
        echo "Examples:"
        echo "  jwweb_json https://api.github.com"
        echo "  jwweb_json api.example.com/v1/health"
        echo
        echo "GET + walidacja/pretty-print JSON (jq) + status/rozmiar. Niepoprawny JSON → surowe body."
        [ $# -eq 0 ] && return 1 || return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        echo "❌ curl nie jest dostępny" >&2; return 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "❌ jwweb_json wymaga 'jq'" >&2; return 1
    fi

    local url="$1"
    case "$url" in http://*|https://*) ;; *) url="https://$url" ;; esac

    local resp="" body="" meta="" code="" ctype="" size="" hmark=""
    resp="$(curl -sS -L -H 'Accept: application/json' \
        -w '\n__JWJSON_META__\t%{http_code}\t%{content_type}\t%{size_download}' "$url" 2>/dev/null)"
    [ -z "$resp" ] && { echo "❌ brak odpowiedzi z $url" >&2; return 1; }
    body="${resp%$'\n'__JWJSON_META__*}"
    meta="${resp##*__JWJSON_META__$'\t'}"
    code="$(printf '%s' "$meta" | cut -f1)"
    ctype="$(printf '%s' "$meta" | cut -f2)"
    size="$(printf '%s' "$meta" | cut -f3)"
    case "$code" in
        2*)      hmark="✅ $code" ;;
        3*)      hmark="↪ $code" ;;
        000|"")  hmark="❌ brak odpowiedzi" ;;
        4*|5*)   hmark="❌ $code" ;;
        *)       hmark="$code" ;;
    esac

    local valid=0
    printf '%s' "$body" | jq empty >/dev/null 2>&1 && valid=1

    echo
    echo "---[ JSON GET: $url ]---"
    __jwweb_kv__ "Status" "$hmark" 14
    [ -n "$ctype" ] && __jwweb_kv__ "Content-Type" "$ctype"    14
    [ -n "$size" ]  && __jwweb_kv__ "Size"         "${size} B" 14
    if [ "$valid" -eq 1 ]; then
        __jwweb_kv__ "Valid JSON" "✅" 14
        echo
        echo "---[ Body ]---"
        printf '%s' "$body" | jq .
    else
        __jwweb_kv__ "Valid JSON" "❌ (parse error)" 14
        echo
        echo "---[ Body (raw) ]---"
        printf '%s\n' "$body"
    fi
    return 0
}


# ---------------------------------------------------------------------------------
# TLS / certyfikaty
# ---------------------------------------------------------------------------------

# 🟢 Full certificate inspection — subject / SAN / issuer / validity / serial.
jwweb_cert() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwweb_cert <host[:port]|url>"
        echo "Examples:"
        echo "  jwweb_cert example.com"
        echo "  jwweb_cert example.com:8443"
        echo "  jwweb_cert https://example.com/foo"
        echo
        echo "Pełna inspekcja certyfikatu TLS (subject/SAN/issuer/ważność/serial/proto)."
        [ $# -eq 0 ] && return 1 || return 0
    fi
    if ! command -v openssl >/dev/null 2>&1; then
        echo "❌ openssl nie jest dostępny" >&2; return 1
    fi

    local scheme="" host="" port="" pth=""
    read -r scheme host port pth <<< "$(__jwweb_parse_url__ "$1")"
    [ -z "$host" ] && { echo "❌ brak host" >&2; return 1; }

    local sout=""
    sout="$(__jwweb_tls_fetch__ "$host" "$port" "$host")"
    [ -z "$sout" ] && { echo "❌ nie udało się połączyć z $host:$port" >&2; return 1; }

    local x509=""
    x509="$(printf '%s\n' "$sout" | openssl x509 -noout -subject -issuer -startdate -enddate -serial 2>/dev/null)"
    [ -z "$x509" ] && { echo "❌ brak certyfikatu z $host:$port" >&2; return 1; }

    local subject="" issuer="" notbefore="" notafter="" serial="" san="" cn="" iss=""
    subject="$(printf '%s\n' "$x509" | grep '^subject=' | sed 's/^subject=//')"
    issuer="$(printf '%s\n' "$x509" | grep '^issuer=' | sed 's/^issuer=//')"
    notbefore="$(printf '%s\n' "$x509" | grep '^notBefore=' | sed 's/^notBefore=//')"
    notafter="$(printf '%s\n' "$x509" | grep '^notAfter=' | sed 's/^notAfter=//')"
    serial="$(printf '%s\n' "$x509" | grep '^serial=' | sed 's/^serial=//')"
    san="$(printf '%s\n' "$sout" | openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -i 'DNS:\|IP Address:' | sed 's/^[[:space:]]*//')"
    cn="$(printf '%s' "$subject" | grep -oE 'CN *= *[^,/]+' | head -1 | sed 's/CN *= *//')"
    iss="$(printf '%s' "$issuer" | grep -oE 'CN *= *[^,/]+' | head -1 | sed 's/CN *= *//')"
    [ -z "$cn" ]  && cn="$subject"
    [ -z "$iss" ] && iss="$issuer"

    local pc="" proto="" cipher="" mark=""
    pc="$(printf '%s\n' "$sout" | __jwweb_protocipher__)"
    proto="$(printf '%s\n' "$pc" | grep '^PROTO ' | sed 's/^PROTO //')"
    cipher="$(printf '%s\n' "$pc" | grep '^CIPHER ' | sed 's/^CIPHER //')"

    local ee="" nn="" days=""
    ee="$(date -d "$notafter" +%s 2>/dev/null)"
    nn="$(date +%s)"
    if [ -n "$ee" ]; then
        days=$(( (ee - nn) / 86400 ))
        if   [ "$days" -lt 0 ];  then mark="❌ WYGASŁ (${days} d)"
        elif [ "$days" -le 7 ];  then mark="❌ $days"
        elif [ "$days" -le 30 ]; then mark="⚠️ $days"
        else                          mark="✅ $days"
        fi
    fi

    local kw=12
    echo
    echo "---[ TLS certificate: $host:$port ]---"
    __jwweb_kv__ "Host"       "$host:$port" "$kw"
    __jwweb_kv__ "Subject CN" "$cn"         "$kw"
    [ -n "$san" ]      && __jwweb_kv__ "SAN"        "$san"        "$kw"
    __jwweb_kv__ "Issuer CN"  "$iss"        "$kw"
    [ -n "$serial" ]   && __jwweb_kv__ "Serial"     "$serial"     "$kw"
    __jwweb_kv__ "Valid from" "$notbefore"  "$kw"
    __jwweb_kv__ "Valid to"   "$notafter"   "$kw"
    [ -n "$mark" ]     && __jwweb_kv__ "Days left"  "$mark"       "$kw"
    [ -n "$proto" ]    && __jwweb_kv__ "Protocol"   "$proto${cipher:+ / $cipher}" "$kw"
    echo
    return 0
}

# 🟢 Days until a TLS certificate expires, with --warn/--crit thresholds.
# Default exit: 0 success / 1 usage|błąd. With --exit-code (opt-in, nagios-style):
# 0 ok / 1 warn / 2 crit|wygasły / 3 błąd.
jwweb_cert-expiry() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwweb_cert-expiry <host[:port]|url> [--warn DAYS] [--crit DAYS] [--exit-code]"
        echo "Examples:"
        echo "  jwweb_cert-expiry example.com"
        echo "  jwweb_cert-expiry example.com:8443 --warn 45 --crit 10"
        echo "  jwweb_cert-expiry https://example.com/foo --exit-code"
        echo
        echo "Dni do wygaśnięcia certyfikatu TLS. --exit-code: 0 ok / 1 warn / 2 crit|wygasły / 3 błąd."
        [ $# -eq 0 ] && return 1 || return 0
    fi
    if ! command -v openssl >/dev/null 2>&1; then
        echo "❌ openssl nie jest dostępny" >&2; return 1
    fi

    local target="" warn=30 crit=7 usecode=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --warn)      warn="$2"; shift 2 ;;
            --crit)      crit="$2"; shift 2 ;;
            --exit-code) usecode=1; shift ;;
            -h|--help)   shift ;;
            -*)          echo "⚠️ nieznana opcja: $1" >&2; shift ;;
            *)           [ -z "$target" ] && target="$1"; shift ;;
        esac
    done
    [ -z "$target" ] && { echo "❌ brak host" >&2; return 1; }

    local scheme="" host="" port="" pth=""
    read -r scheme host port pth <<< "$(__jwweb_parse_url__ "$target")"

    local fields=""
    fields="$(__jwweb_cert_enddate__ "$host" "$port" "$host")"
    if [ -z "$fields" ]; then
        echo "❌ nie udało się pobrać certyfikatu z $host:$port" >&2
        [ "$usecode" -eq 1 ] && return 3 || return 1
    fi

    local notafter="" subject="" issuer="" cn="" iss=""
    notafter="$(printf '%s\n' "$fields" | grep '^notAfter=' | sed 's/^notAfter=//')"
    subject="$(printf '%s\n' "$fields" | grep '^subject=' | sed 's/^subject=//')"
    issuer="$(printf '%s\n' "$fields" | grep '^issuer=' | sed 's/^issuer=//')"
    cn="$(printf '%s' "$subject" | grep -oE 'CN *= *[^,/]+' | head -1 | sed 's/CN *= *//')"
    iss="$(printf '%s' "$issuer" | grep -oE 'CN *= *[^,/]+' | head -1 | sed 's/CN *= *//')"
    [ -z "$cn" ] && cn="$subject"
    [ -z "$iss" ] && iss="$issuer"

    local endepoch="" nowepoch="" days="" mark="" sev=0
    endepoch="$(date -d "$notafter" +%s 2>/dev/null)"
    nowepoch="$(date +%s)"
    if [ -z "$endepoch" ]; then
        echo "❌ nie sparsowałem daty: $notafter" >&2
        [ "$usecode" -eq 1 ] && return 3 || return 1
    fi
    days=$(( (endepoch - nowepoch) / 86400 ))
    if   [ "$days" -lt 0 ];          then mark="❌ WYGASŁ (${days} d)"; sev=2
    elif [ "$days" -le "$crit" ];    then mark="❌ $days";             sev=2
    elif [ "$days" -le "$warn" ];    then mark="⚠️ $days";             sev=1
    else                                  mark="✅ $days";             sev=0
    fi

    echo
    echo "---[ TLS certificate: $host:$port ]---"
    __jwweb_kv__ "Host"       "$host:$port" 12
    __jwweb_kv__ "Subject CN" "$cn"         12
    __jwweb_kv__ "Issuer"     "$iss"        12
    __jwweb_kv__ "Not after"  "$notafter"   12
    __jwweb_kv__ "Days left"  "$mark"       12
    echo

    [ "$usecode" -eq 1 ] && return "$sev"
    return 0
}

# 🟢 Negotiated protocol/cipher + supported TLS-version probe (TLS 1.0–1.3).
jwweb_tls() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwweb_tls <host[:port]|url>"
        echo "Examples:"
        echo "  jwweb_tls example.com"
        echo "  jwweb_tls example.com:8443"
        echo
        echo "Wynegocjowany protokół/cipher + sonda wspieranych wersji (TLS 1.0–1.3; stare = ⚠️)."
        [ $# -eq 0 ] && return 1 || return 0
    fi
    if ! command -v openssl >/dev/null 2>&1; then
        echo "❌ openssl nie jest dostępny" >&2; return 1
    fi

    local scheme="" host="" port="" pth=""
    read -r scheme host port pth <<< "$(__jwweb_parse_url__ "$1")"
    [ -z "$host" ] && { echo "❌ brak host" >&2; return 1; }

    local sout="" pc="" proto="" cipher=""
    sout="$(__jwweb_tls_fetch__ "$host" "$port" "$host")"
    [ -z "$sout" ] && { echo "❌ nie udało się połączyć z $host:$port" >&2; return 1; }
    pc="$(printf '%s\n' "$sout" | __jwweb_protocipher__)"
    proto="$(printf '%s\n' "$pc" | grep '^PROTO ' | sed 's/^PROTO //')"
    cipher="$(printf '%s\n' "$pc" | grep '^CIPHER ' | sed 's/^CIPHER //')"

    echo
    echo "---[ TLS: $host:$port ]---"
    __jwweb_kv__ "Negotiated" "${proto:-?}${cipher:+ / $cipher}" 12

    echo
    echo "---[ Supported versions ]---"
    local spec="" lbl="" rest="" flag="" cls=""
    for spec in "TLS 1.0|-tls1|old" "TLS 1.1|-tls1_1|old" "TLS 1.2|-tls1_2|ok" "TLS 1.3|-tls1_3|ok"; do
        lbl="${spec%%|*}"
        rest="${spec#*|}"
        flag="${rest%%|*}"
        cls="${rest##*|}"
        if echo | openssl s_client -connect "$host:$port" -servername "$host" "$flag" 2>/dev/null \
            | grep -q 'BEGIN CERTIFICATE'; then
            if [ "$cls" = "old" ]; then
                __jwweb_kv__ "$lbl" "⚠️ tak (przestarzałe)" 10
            else
                __jwweb_kv__ "$lbl" "✅ tak" 10
            fi
        else
            __jwweb_kv__ "$lbl" "✗ nie" 10
        fi
    done
    echo
    return 0
}


# ---------------------------------------------------------------------------------
# DNS
# ---------------------------------------------------------------------------------

# 🟢 DNS resolution — CNAME / A / AAAA for a host (dig → host → getent).
jwweb_dns() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwweb_dns <host|url>"
        echo "Examples:"
        echo "  jwweb_dns example.com"
        echo "  jwweb_dns https://example.com/path"
        echo
        echo "Rozwiązanie DNS: CNAME / A / AAAA. CNAME tylko gdy dostępny dig."
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local target="$1" host=""
    case "$target" in
        http://*|https://*|*/*|*:*)
            local scheme="" port="" pth=""
            read -r scheme host port pth <<< "$(__jwweb_parse_url__ "$target")"
            ;;
        *) host="$target" ;;
    esac
    [ -z "$host" ] && { echo "❌ brak host" >&2; return 1; }

    local kw=10
    echo
    echo "---[ DNS: $host ]---"
    local cname=""
    command -v dig >/dev/null 2>&1 && \
        cname="$(dig +short CNAME "$host" 2>/dev/null | head -1 | sed 's/\.$//')"

    local dnsout="" rline="" line="" hasip=0
    dnsout="$(__jwweb_resolve__ "$host")"
    rline="$(printf '%s\n' "$dnsout" | grep '^RESOLVER ' | head -1 | sed 's/^RESOLVER //')"
    [ -n "$rline" ]  && __jwweb_kv__ "Resolver" "$rline"  "$kw"
    [ -n "$cname" ]  && __jwweb_kv__ "CNAME"    "$cname"  "$kw"
    while IFS= read -r line; do
        case "$line" in
            "A "*)    __jwweb_kv__ "A"    "${line#A }"    "$kw"; hasip=1 ;;
            "AAAA "*) __jwweb_kv__ "AAAA" "${line#AAAA }" "$kw"; hasip=1 ;;
        esac
    done <<< "$dnsout"
    [ "$hasip" -eq 0 ] && __jwweb_kv__ "Result" "❌ brak rekordów A/AAAA" "$kw"
    echo
    return 0
}

# 🟢 DNS propagation — query one record from several resolvers, flag divergence.
jwweb_dns-prop() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwweb_dns-prop <host|url> [type]"
        echo "Examples:"
        echo "  jwweb_dns-prop example.com"
        echo "  jwweb_dns-prop example.com AAAA"
        echo
        echo "Pyta o rekord (default A) z system/1.1.1.1/8.8.8.8/9.9.9.9 i wskazuje rozbieżność."
        [ $# -eq 0 ] && return 1 || return 0
    fi
    if ! command -v dig >/dev/null 2>&1; then
        echo "❌ jwweb_dns-prop wymaga 'dig' (apt install dnsutils)" >&2; return 1
    fi

    local scheme="" host="" port="" pth=""
    read -r scheme host port pth <<< "$(__jwweb_parse_url__ "$1")"
    [ -z "$host" ] && { echo "❌ brak host" >&2; return 1; }
    local rtype="${2:-A}"

    echo
    echo "---[ DNS propagation: $host ($rtype) ]---"
    local kw=10
    local r="" out="" first="" idx=0 mism=0
    for r in system 1.1.1.1 8.8.8.8 9.9.9.9; do
        if [ "$r" = "system" ]; then
            out="$(dig +short "$rtype" "$host" 2>/dev/null | grep -vE '^;' | sort | paste -sd, - | sed 's/,/, /g')"
        else
            out="$(dig +short "@$r" "$rtype" "$host" 2>/dev/null | grep -vE '^;' | sort | paste -sd, - | sed 's/,/, /g')"
        fi
        [ -z "$out" ] && out="(brak)"
        __jwweb_kv__ "$r" "$out" "$kw"
        if [ "$idx" -eq 0 ]; then first="$out"; elif [ "$out" != "$first" ]; then mism=1; fi
        idx=$((idx + 1))
    done
    if [ "$mism" -eq 1 ]; then
        __jwweb_kv__ "Consensus" "❌ rozbieżność między resolverami" "$kw"
    else
        __jwweb_kv__ "Consensus" "✅ wszystkie resolvery zgodne" "$kw"
    fi
    echo
    return 0
}

# 🟢 Domain registration data — RDAP-first (rdap.org), whois fallback.
jwweb_domain() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwweb_domain <domain|url>"
        echo "Examples:"
        echo "  jwweb_domain example.com"
        echo "  jwweb_domain https://example.com/path"
        echo
        echo "Rejestracja domeny: RDAP-first (JSON, rdap.org) z fallbackiem na whois."
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local scheme="" domain="" port="" pth=""
    read -r scheme domain port pth <<< "$(__jwweb_parse_url__ "$1")"
    [ -z "$domain" ] && { echo "❌ brak domeny" >&2; return 1; }

    local src="" registrar="" created="" expires="" updated="" dstat="" ns="" dnssec=""

    # --- RDAP first (structured JSON) ---
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        local rdap="" kv=""
        rdap="$(curl -sSL --max-time 15 -H 'Accept: application/rdap+json' \
            "https://rdap.org/domain/$domain" 2>/dev/null)"
        if printf '%s' "$rdap" | jq -e '.objectClassName=="domain"' >/dev/null 2>&1; then
            kv="$(printf '%s' "$rdap" | jq -r '
                def ev(a): ([.events[]?|select(.eventAction==a)|.eventDate]|first) // "";
                "REGISTRAR\t" + (([.entities[]?|select(.roles and (.roles|index("registrar")))|.vcardArray[1][]?|select(.[0]=="fn")|.[3]]|first) // ""),
                "CREATED\t"   + ev("registration"),
                "EXPIRES\t"   + ev("expiration"),
                "UPDATED\t"   + ev("last changed"),
                "STATUS\t"    + ((.status // [])|join(", ")),
                "NS\t"        + (([.nameservers[]?.ldhName])|join(", ")),
                "DNSSEC\t"    + ((.secureDNS.delegationSigned // false)|tostring)
            ' 2>/dev/null)"
            registrar="$(printf '%s\n' "$kv" | grep '^REGISTRAR' | cut -f2-)"
            created="$(printf   '%s\n' "$kv" | grep '^CREATED'   | cut -f2- | sed 's/T.*//')"
            expires="$(printf   '%s\n' "$kv" | grep '^EXPIRES'   | cut -f2- | sed 's/T.*//')"
            updated="$(printf   '%s\n' "$kv" | grep '^UPDATED'   | cut -f2- | sed 's/T.*//')"
            dstat="$(printf     '%s\n' "$kv" | grep '^STATUS'    | cut -f2-)"
            ns="$(printf        '%s\n' "$kv" | grep '^NS'        | cut -f2-)"
            dnssec="$(printf    '%s\n' "$kv" | grep '^DNSSEC'    | cut -f2-)"
            src="RDAP"
        fi
    fi

    # --- whois fallback (free-text, best-effort parse) ---
    if [ -z "$src" ] && command -v whois >/dev/null 2>&1; then
        local who=""
        who="$(whois "$domain" 2>/dev/null)"
        if [ -n "$who" ]; then
            registrar="$(printf '%s\n' "$who" | grep -iE '^[[:space:]]*Registrar:' | head -1 | sed 's/^[^:]*:[[:space:]]*//')"
            created="$(printf   '%s\n' "$who" | grep -iE '^[[:space:]]*Creation Date:' | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/T.*//')"
            expires="$(printf   '%s\n' "$who" | grep -iE 'Expir(y|ation) Date:' | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/T.*//')"
            updated="$(printf   '%s\n' "$who" | grep -iE '^[[:space:]]*Updated Date:' | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/T.*//')"
            dstat="$(printf     '%s\n' "$who" | grep -iE '^[[:space:]]*Domain Status:' | sed 's/^[^:]*:[[:space:]]*//' | awk '{print $1}' | sort -u | paste -sd, - | sed 's/,/, /g')"
            ns="$(printf        '%s\n' "$who" | grep -iE '^[[:space:]]*Name Server:' | sed 's/^[^:]*:[[:space:]]*//' | tr '[:upper:]' '[:lower:]' | sort -u | paste -sd, - | sed 's/,/, /g')"
            dnssec="$(printf    '%s\n' "$who" | grep -iE '^[[:space:]]*DNSSEC:' | head -1 | sed 's/^[^:]*:[[:space:]]*//')"
            src="whois (fallback)"
        fi
    fi

    [ -z "$src" ] && { echo "❌ brak danych RDAP/whois dla $domain" >&2; return 1; }

    # days-to-expiry marker
    local mark="" ee="" nn="" days=""
    if [ -n "$expires" ]; then
        ee="$(date -d "$expires" +%s 2>/dev/null)"
        nn="$(date +%s)"
        if [ -n "$ee" ]; then
            days=$(( (ee - nn) / 86400 ))
            if   [ "$days" -lt 0 ];  then mark="❌ WYGASŁA (${days} d)"
            elif [ "$days" -le 7 ];  then mark="❌ $days d"
            elif [ "$days" -le 30 ]; then mark="⚠️ $days d"
            else                          mark="✅ $days d"
            fi
        fi
    fi

    # dnssec normalize (unsigned checked first: "unsigned" contains "igned")
    local dnsm=""
    case "$dnssec" in
        false|*nsigned*) dnsm="— niepodpisany" ;;
        true|*igned*)    dnsm="✅ signed" ;;
        "")              dnsm="—" ;;
        *)               dnsm="$dnssec" ;;
    esac

    local kw=13
    echo
    echo "---[ Domain: $domain ]---"
    __jwweb_kv__ "Source" "$src" "$kw"
    [ -n "$registrar" ] && __jwweb_kv__ "Registrar"   "$registrar" "$kw"
    [ -n "$created" ]   && __jwweb_kv__ "Created"     "$created"   "$kw"
    [ -n "$expires" ]   && __jwweb_kv__ "Expires"     "$expires${mark:+   ($mark)}" "$kw"
    [ -n "$updated" ]   && __jwweb_kv__ "Updated"     "$updated"   "$kw"
    [ -n "$dstat" ]     && __jwweb_kv__ "Status"      "$dstat"     "$kw"
    [ -n "$ns" ]        && __jwweb_kv__ "Nameservers" "$ns"        "$kw"
    __jwweb_kv__ "DNSSEC" "$dnsm" "$kw"
    echo
    return 0
}


# ---------------------------------------------------------------------------------
# łączność / osiągalność
# ---------------------------------------------------------------------------------

# 🟢 TCP port reachability — one or more ports on a host (nc → bash /dev/tcp).
jwweb_port() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwweb_port <host|url> [port ...]"
        echo "Examples:"
        echo "  jwweb_port example.com 443"
        echo "  jwweb_port example.com 80 443 8080"
        echo "  jwweb_port https://example.com         # port z URL-a (443)"
        echo
        echo "Sprawdza otwartość portów TCP. Bez podanego portu bierze go z URL-a/443."
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local target="$1"; shift
    local scheme="" host="" defport="" pth=""
    read -r scheme host defport pth <<< "$(__jwweb_parse_url__ "$target")"
    [ -z "$host" ] && { echo "❌ brak host" >&2; return 1; }

    local ports=()
    if [ $# -gt 0 ]; then ports=("$@"); else ports=("$defport"); fi

    echo
    echo "---[ TCP ports: $host ]---"
    local p="" rc=0
    for p in "${ports[@]}"; do
        __jwweb_tcp_probe__ "$host" "$p"; rc=$?
        case "$rc" in
            0) __jwweb_kv__ "$p" "✅ open"               8 ;;
            2) __jwweb_kv__ "$p" "⚠️ pominięto (brak nc)" 8 ;;
            *) __jwweb_kv__ "$p" "❌ closed/filtered"    8 ;;
        esac
    done
    echo
    return 0
}


# ---------------------------------------------------------------------------------
# diagnostyka zbiorcza
# ---------------------------------------------------------------------------------

# 🟢 One-shot endpoint health report: DNS → TCP → TLS → HTTP → timing → sec headers.
# Hard-aborts only on DNS failure; a missing tool marks its stage "⚠️ pominięto".
jwweb_diag() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwweb_diag <url> [--port N]"
        echo "Examples:"
        echo "  jwweb_diag example.com"
        echo "  jwweb_diag https://api.example.com/v1"
        echo "  jwweb_diag example.com --port 8443"
        echo
        echo "Raport health endpointu: DNS → TCP → TLS → HTTP → timing → security headers."
        [ $# -eq 0 ] && return 1 || return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        echo "❌ curl nie jest dostępny" >&2; return 1
    fi

    local url="" portovr=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --port)    portovr="$2"; shift 2 ;;
            -h|--help) shift ;;
            -*)        echo "⚠️ nieznana opcja: $1" >&2; shift ;;
            *)         [ -z "$url" ] && url="$1"; shift ;;
        esac
    done
    [ -z "$url" ] && { echo "❌ brak URL" >&2; return 1; }
    case "$url" in http://*|https://*) ;; *) url="https://$url" ;; esac

    local scheme="" host="" port="" pth=""
    read -r scheme host port pth <<< "$(__jwweb_parse_url__ "$url")"
    [ -n "$portovr" ] && port="$portovr"

    local kw=14
    local v_dns="∅" v_tcp="∅" v_tls="—" v_http="∅"

    echo
    echo "---[ web diag: $url ]---"
    __jwweb_kv__ "Target" "$scheme / $host / $port / $pth" "$kw"

    # --- DNS (hard prerequisite) ---
    echo
    echo "---[ DNS ]---"
    local dnsout="" rline="" line="" hasip=0
    dnsout="$(__jwweb_resolve__ "$host")"
    rline="$(printf '%s\n' "$dnsout" | grep '^RESOLVER ' | head -1 | sed 's/^RESOLVER //')"
    [ -n "$rline" ] && __jwweb_kv__ "Resolver" "$rline" "$kw"
    while IFS= read -r line; do
        case "$line" in
            "A "*)    __jwweb_kv__ "A"    "${line#A }"    "$kw"; hasip=1 ;;
            "AAAA "*) __jwweb_kv__ "AAAA" "${line#AAAA }" "$kw"; hasip=1 ;;
        esac
    done <<< "$dnsout"
    if [ "$hasip" -eq 0 ]; then
        __jwweb_kv__ "Result" "❌ brak rekordów A/AAAA — przerywam" "$kw"
        echo
        echo "---[ Verdict ]---"
        echo "❌ DNS"
        echo
        return 1
    fi
    v_dns="✅"

    # --- TCP ---
    echo
    echo "---[ TCP :$port ]---"
    local tcprc=0
    __jwweb_tcp_probe__ "$host" "$port"; tcprc=$?
    case "$tcprc" in
        0) __jwweb_kv__ "Reachable" "✅ open"               "$kw"; v_tcp="✅" ;;
        2) __jwweb_kv__ "Reachable" "⚠️ pominięto (brak nc)" "$kw"; v_tcp="⚠️" ;;
        *) __jwweb_kv__ "Reachable" "❌ closed/filtered"    "$kw"; v_tcp="❌" ;;
    esac

    # --- TLS (https only) ---
    if [ "$scheme" = "https" ]; then
        echo
        echo "---[ TLS ]---"
        if command -v openssl >/dev/null 2>&1; then
            local cfields="" proto="" cipher="" notafter="" subject="" cn="" days="" ee="" nn=""
            cfields="$(__jwweb_cert_enddate__ "$host" "$port" "$host")"
            if [ -n "$cfields" ]; then
                proto="$(printf '%s\n' "$cfields" | grep '^PROTO ' | sed 's/^PROTO //')"
                cipher="$(printf '%s\n' "$cfields" | grep '^CIPHER ' | sed 's/^CIPHER //')"
                notafter="$(printf '%s\n' "$cfields" | grep '^notAfter=' | sed 's/^notAfter=//')"
                subject="$(printf '%s\n' "$cfields" | grep '^subject=' | sed 's/^subject=//')"
                cn="$(printf '%s' "$subject" | grep -oE 'CN *= *[^,/]+' | head -1 | sed 's/CN *= *//')"
                [ -z "$cn" ] && cn="$subject"
                [ -n "$proto" ] && __jwweb_kv__ "Protocol" "$proto${cipher:+ / $cipher}" "$kw"
                [ -n "$cn" ]    && __jwweb_kv__ "Subject CN" "$cn" "$kw"
                ee="$(date -d "$notafter" +%s 2>/dev/null)"
                nn="$(date +%s)"
                if [ -n "$ee" ]; then
                    days=$(( (ee - nn) / 86400 ))
                    if   [ "$days" -lt 0 ];  then __jwweb_kv__ "Days left" "❌ WYGASŁ" "$kw"
                    elif [ "$days" -le 7 ];  then __jwweb_kv__ "Days left" "❌ $days"  "$kw"
                    elif [ "$days" -le 30 ]; then __jwweb_kv__ "Days left" "⚠️ $days"  "$kw"
                    else                          __jwweb_kv__ "Days left" "✅ $days"  "$kw"
                    fi
                fi
                v_tls="✅"
            else
                __jwweb_kv__ "Result" "❌ handshake nieudany" "$kw"; v_tls="❌"
            fi
        else
            __jwweb_kv__ "Result" "⚠️ pominięto (brak openssl)" "$kw"; v_tls="⚠️"
        fi
    fi

    # --- HTTP + timing (one curl call) ---
    local winfo=""
    winfo="$(curl -sS -o /dev/null -L \
        -w 'CODE=%{http_code}\nURL=%{url_effective}\nREDIR=%{num_redirects}\nCTYPE=%{content_type}\nT_DNS=%{time_namelookup}\nT_CONN=%{time_connect}\nT_TLS=%{time_appconnect}\nT_TTFB=%{time_starttransfer}\nT_TOTAL=%{time_total}\n' \
        "$url" 2>/dev/null)"

    echo
    echo "---[ HTTP ]---"
    local code="" finalurl="" nredir="" ctype="" hmark=""
    code="$(printf '%s\n' "$winfo" | grep '^CODE=' | cut -d= -f2)"
    finalurl="$(printf '%s\n' "$winfo" | grep '^URL=' | cut -d= -f2-)"
    nredir="$(printf '%s\n' "$winfo" | grep '^REDIR=' | cut -d= -f2)"
    ctype="$(printf '%s\n' "$winfo" | grep '^CTYPE=' | cut -d= -f2-)"
    case "$code" in
        2*)      hmark="✅ $code"; v_http="✅" ;;
        3*)      hmark="↪ $code";  v_http="✅" ;;
        000|"")  hmark="❌ brak odpowiedzi"; v_http="❌" ;;
        4*|5*)   hmark="❌ $code"; v_http="❌" ;;
        *)       hmark="$code";    v_http="⚠️" ;;
    esac
    __jwweb_kv__ "Status" "$hmark" "$kw"
    [ -n "$finalurl" ] && __jwweb_kv__ "Final URL" "$finalurl  (${nredir:-0} redirects)" "$kw"
    [ -n "$ctype" ]    && __jwweb_kv__ "Content-Type" "$ctype" "$kw"

    echo
    echo "---[ Timing ]---"
    local t_dns="" t_conn="" t_tls="" t_ttfb="" t_total=""
    t_dns="$(printf   '%s\n' "$winfo" | grep '^T_DNS='   | cut -d= -f2)"
    t_conn="$(printf  '%s\n' "$winfo" | grep '^T_CONN='  | cut -d= -f2)"
    t_tls="$(printf   '%s\n' "$winfo" | grep '^T_TLS='   | cut -d= -f2)"
    t_ttfb="$(printf  '%s\n' "$winfo" | grep '^T_TTFB='  | cut -d= -f2)"
    t_total="$(printf '%s\n' "$winfo" | grep '^T_TOTAL=' | cut -d= -f2)"
    __jwweb_print_timing__ "$scheme" "$t_dns" "$t_conn" "$t_tls" "$t_ttfb" "$t_total"

    # --- Security headers ---
    echo
    echo "---[ Security headers ]---"
    local dhdr="" dcode=""
    dhdr="$(curl -sS -I -L "$url" 2>/dev/null | tr -d '\r')"
    dcode="$(printf '%s\n' "$dhdr" | grep -E '^HTTP/' | tail -1 | awk '{print $2}')"
    case "$dcode" in
        405|501|"") dhdr="$(curl -sS -L -o /dev/null -D - "$url" 2>/dev/null | tr -d '\r')" ;;
    esac
    printf '%s\n' "$dhdr" | awk '/^HTTP\//{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' \
        | __jwweb_sec_headers__

    # --- Verdict ---
    echo
    echo "---[ Verdict ]---"
    local tlsbit=""
    [ "$v_tls" != "—" ] && tlsbit=" · $v_tls TLS"
    echo "$v_dns DNS · $v_tcp TCP$tlsbit · $v_http HTTP ${code}"
    echo

    return 0
}
