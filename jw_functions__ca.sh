# shellcheck shell=bash

# ---------------------------------------------------------------------------------
# table of contents
# ---------------------------------------------------------------------------------
#
# Oversight-first area — the cockpit for the LOCAL trust store and local certificate
# files: quick tools that answer "what does THIS machine trust, is that set healthy,
# and what is inside this .pem?". Its axis is deliberately the mirror image of the
# web area: jwweb_cert* probe a REMOTE endpoint over a live TLS handshake ("does that
# server present a valid chain?"); the tools here never open a socket — they read the
# local corpus of trust (/etc/ssl/certs, /usr/local/share/ca-certificates) and local
# cert/key objects.
#
# Everything is 🟢 read-only. Changing the trust store means writing under /etc and
# running update-ca-certificates — a root action. Rather than shell out to sudo from
# a sourced function, this area follows the oversight-first "show the mutation, don't
# do it" contract: the change surface (add/remove a CA — a later addition) will VALIDATE
# the input and PRINT the exact copy-paste sudo command, never run it. So the area stays
# safe to run blindly, and mutation stays a deliberate, visible act by the human.
#
# Server-safe: openssl + the ca-certificates layout are the only hard requirements
# (both ship on every Ubuntu/Debian). Optional inspectors of OTHER trust stores
# (p11-kit `trust`, NSS `certutil`, Java `keytool`, Python `certifi`, Node) are probed
# and gracefully skipped when absent — jwca_stores reports what it can detect and flags
# the KNOWN cross-store gotchas honestly, never asserting a blanket claim it did not verify.
#
# Built incrementally (greenfield). jwca_toc() is the live index.

# One TOC row: blast-radius marker, padded function name, one-line "soul" tagline.
# printf is byte-width (identical bash/zsh); the marker sits in a fixed slot on
# every row, so the tagline column aligns regardless of emoji width.
__jwca_toc_row__() {
    printf " - %s %-17s%s\n" "$1" "$2" "$3"
}

jwca_toc() {
    echo
    echo "   blast radius:  🟢 read-only   🔵 creates   ⚪ state change / transfer   🔴 destructive"
    echo "   (oversight-first: every tool is read-only; changes to the store are printed, never run)"
    echo
    echo " -----------------------------  system trust store"
    __jwca_toc_row__ 🟢 jwca_store  "posture: counts/drift/expired"
    __jwca_toc_row__ 🟢 jwca_list   "every trusted CA, full"
    __jwca_toc_row__ 🟢 jwca_custom "admin-added + disabled CAs"
    echo
    echo " -----------------------------  local cert files"
    __jwca_toc_row__ 🟢 jwca_inspect "fields+fingerprints+usage"
    echo
    echo " -----------------------------  cross-store"
    __jwca_toc_row__ 🟢 jwca_stores "system/NSS/Java/certifi map"
    __jwca_toc_row__ 🟢 jwca_nss    "browser (NSS) added CAs"
    echo
}


# ---------------------------------------------------------------------------------
# internal helpers
# ---------------------------------------------------------------------------------

# The Debian/Ubuntu trust-store layout — the substrate every tool here reads.
_jwca_bundle_="/etc/ssl/certs/ca-certificates.crt"   # the generated PEM bundle tools read
_jwca_local_="/usr/local/share/ca-certificates"      # admin-added local CAs (*.crt, PEM)
_jwca_conf_="/etc/ca-certificates.conf"              # active/disabled ('!') selection
_jwca_pkg_="/usr/share/ca-certificates"              # certs shipped by the ca-certificates package

# Column-align "Label  value" rows in grouped info blocks. Optional 3rd arg overrides
# the column width (default 14). Labels ASCII (printf is byte-width, identical bash/zsh).
__jwca_kv__() {
    printf "%-${3:-14}s%s\n" "$1" "$2"
}

# A section header "---[ Title ]---", rendered bold + yellow via jw_colors.sh's
# jwpaintfg* helpers when that file is sourced; plain otherwise — so this file works
# sourced standalone (no raw ANSI here, no hard dependency on jw_colors.sh).
__jwca_h__() {
    if command -v jwpaintfgBold >/dev/null 2>&1 && command -v jwpaintfgYellow >/dev/null 2>&1; then
        jwpaintfgBold "$(jwpaintfgYellow "---[ $1 ]---")"
    else
        echo "---[ $1 ]---"
    fi
}

# Detect a certificate file's encoding without trusting its extension (.crt files are
# often PEM, sometimes DER). Echoes "pem" / "der" / "" (not a certificate). Callers turn
# a "der" into the openssl `-inform DER` args.
__jwca_certform__() {
    # Force -inform PEM: openssl 3.x auto-detects DER even without it, so a bare
    # `-in` "succeeds" on a DER file and would mislabel it PEM. Forcing the input
    # format disables autodetect, so the two branches actually distinguish.
    local f="$1"
    if openssl x509 -inform PEM -in "$f" -noout >/dev/null 2>&1; then
        echo "pem"
    elif openssl x509 -inform DER -in "$f" -noout >/dev/null 2>&1; then
        echo "der"
    else
        echo ""
    fi
}

# Value of one X509v3 extension, header line stripped and folded to a single line —
# e.g. __jwca_x509_ext__ cert.pem 0 basicConstraints -> "CA:TRUE, pathlen:0". $2 is the
# DER flag (1 = DER-encoded input). Empty when the extension is absent.
__jwca_x509_ext__() {
    local f="$1" der="$2" ext="$3" inform=()
    [ "$der" = "1" ] && inform=(-inform DER)
    openssl x509 "${inform[@]}" -in "$f" -noout -ext "$ext" 2>/dev/null \
        | tail -n +2 | sed 's/^[[:space:]]*//' | tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

# The CN out of an openssl subject/issuer DN string ("CN = Foo, O = Bar" -> "Foo").
# Falls back to the whole DN when there is no CN component.
__jwca_cn__() {
    local dn="$1" cn=""
    cn="$(printf '%s' "$dn" | grep -oE 'CN ?= ?[^,/]+' | head -1 | sed -E 's/CN ?= ?//')"
    [ -z "$cn" ] && cn="$dn"
    printf '%s' "$cn"
}

# Days-to-expiry verdict for an openssl notAfter date string:
#   "✅ 400 d" (>30) · "⚠️ 20 d" (≤30) · "❌ 3 d" (≤7) · "❌ EXPIRED (-5 d)" (<0) · "" (unparseable).
# One place for the thresholds — reused by jwca_inspect and jwca_store's expired scan.
__jwca_expiry_mark__() {
    local na="$1" ee nn days
    ee="$(date -d "$na" +%s 2>/dev/null)"
    [ -z "$ee" ] && return
    nn="$(date +%s)"
    days=$(( (ee - nn) / 86400 ))
    if   [ "$days" -lt 0 ];  then echo "❌ EXPIRED (${days} d)"
    elif [ "$days" -le 7 ];  then echo "❌ $days d"
    elif [ "$days" -le 30 ]; then echo "⚠️ $days d"
    else                          echo "✅ $days d"
    fi
}

# Count expired certificates in a PEM bundle. Splits the bundle with a line buffer
# (NOT `read -d ''` — zsh's read has no -d; NOT a glob — zsh errors on no-match), so
# each cert is fed to openssl individually (openssl x509 reads only the first cert of a
# multi-cert stream). One fork per cert; used by the posture X-ray, run occasionally.
__jwca_bundle_expired__() {
    local f="$1" line buf="" n=0 nn end ee
    nn="$(date +%s)"
    while IFS= read -r line; do
        buf+="$line"$'\n'
        case "$line" in
            *'-----END CERTIFICATE-----'*)
                end="$(printf '%s' "$buf" | openssl x509 -noout -enddate 2>/dev/null | sed 's/^notAfter=//')"
                buf=""
                [ -z "$end" ] && continue
                ee="$(date -d "$end" +%s 2>/dev/null)"
                [ -n "$ee" ] && [ "$ee" -lt "$nn" ] && n=$((n + 1))
                ;;
        esac
    done < "$f"
    printf '%s' "$n"
}


# ---------------------------------------------------------------------------------
# local cert files
# ---------------------------------------------------------------------------------

# Deep inspection of a single local certificate file — everything jwweb_cert --file
# shows plus the fields that matter when reasoning about TRUST: both fingerprints
# (SHA-256 + SHA-1), key type & size, signature algorithm, key usage / extended key
# usage, the Basic Constraints CA flag, and whether the cert is self-signed (a root).
# Auto-detects PEM vs DER. Reads only — never opens a socket (that is jwweb_'s lane).
jwca_inspect() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwca_inspect <file>"
        echo "Examples:"
        echo "  jwca_inspect ./server.pem"
        echo "  jwca_inspect /usr/local/share/ca-certificates/corp-root.crt"
        echo
        echo "Deep inspection of a local certificate (PEM or DER): subject/SAN/issuer,"
        echo "validity + days-left, SHA-256/SHA-1 fingerprints, key type & size, signature"
        echo "algorithm, key usage / EKU, the CA flag (Basic Constraints), and self-signed."
        [ $# -eq 0 ] && return 1 || return 0
    fi
    if ! command -v openssl >/dev/null 2>&1; then
        echo "❌ openssl not available" >&2; return 1
    fi
    local f="$1"
    { [ -f "$f" ] && [ -r "$f" ]; } || { echo "❌ cannot read file: $f" >&2; return 1; }

    local form der=0 inform=()
    form="$(__jwca_certform__ "$f")"
    [ -z "$form" ] && { echo "❌ not a valid certificate: $f" >&2; return 1; }
    [ "$form" = "der" ] && { der=1; inform=(-inform DER); }

    local meta txt subj_dn iss_dn serial notbefore notafter cn iss_cn
    meta="$(openssl x509 "${inform[@]}" -in "$f" -noout -subject -issuer -serial -startdate -enddate 2>/dev/null)"
    txt="$(openssl x509 "${inform[@]}" -in "$f" -noout -text 2>/dev/null)"
    subj_dn="$(printf '%s\n' "$meta" | sed -n 's/^subject=//p')"
    iss_dn="$(printf '%s\n' "$meta" | sed -n 's/^issuer=//p')"
    serial="$(printf '%s\n' "$meta" | sed -n 's/^serial=//p')"
    notbefore="$(printf '%s\n' "$meta" | sed -n 's/^notBefore=//p')"
    notafter="$(printf '%s\n' "$meta" | sed -n 's/^notAfter=//p')"
    cn="$(__jwca_cn__ "$subj_dn")"
    iss_cn="$(__jwca_cn__ "$iss_dn")"

    local san fp256 fp1
    san="$(__jwca_x509_ext__ "$f" "$der" subjectAltName)"
    fp256="$(openssl x509 "${inform[@]}" -in "$f" -noout -fingerprint -sha256 2>/dev/null | sed 's/.*=//')"
    fp1="$(openssl x509 "${inform[@]}" -in "$f" -noout -fingerprint -sha1 2>/dev/null | sed 's/.*=//')"

    local keyalgo keybits eccurve key sigalgo
    keyalgo="$(printf '%s\n' "$txt" | grep -m1 'Public Key Algorithm:' | sed 's/.*Public Key Algorithm:[[:space:]]*//')"
    keybits="$(printf '%s\n' "$txt" | grep -m1 -oE 'Public-Key: \([0-9]+ bit\)' | grep -oE '[0-9]+')"
    eccurve="$(printf '%s\n' "$txt" | grep -m1 'ASN1 OID:' | sed 's/.*ASN1 OID:[[:space:]]*//')"
    case "$keyalgo" in
        *rsa*|*RSA*)             key="RSA${keybits:+ $keybits bit}" ;;
        *ecPublicKey*|*id-ec*)   key="EC${eccurve:+ $eccurve}${keybits:+ ($keybits bit)}" ;;
        "")                      key="" ;;
        *)                       key="$keyalgo${keybits:+ $keybits bit}" ;;
    esac
    sigalgo="$(printf '%s\n' "$txt" | grep -m1 'Signature Algorithm:' | sed 's/.*Signature Algorithm:[[:space:]]*//')"

    local ku eku bc isca selfsigned mark
    ku="$(__jwca_x509_ext__ "$f" "$der" keyUsage)"
    eku="$(__jwca_x509_ext__ "$f" "$der" extendedKeyUsage)"
    bc="$(__jwca_x509_ext__ "$f" "$der" basicConstraints)"
    case "$bc" in *CA:TRUE*) isca="yes" ;; *) isca="no" ;; esac
    if [ -n "$subj_dn" ] && [ "$subj_dn" = "$iss_dn" ]; then selfsigned="yes"; else selfsigned="no"; fi
    mark="$(__jwca_expiry_mark__ "$notafter")"

    local formU; formU="$(printf '%s' "$form" | tr '[:lower:]' '[:upper:]')"
    echo
    __jwca_h__ "Certificate: $(basename -- "$f")"
    __jwca_kv__ "Format"      "$formU"
    __jwca_kv__ "Subject"     "$cn"
    [ -n "$san" ]        && __jwca_kv__ "SAN"         "$san"
    __jwca_kv__ "Issuer"      "$iss_cn"
    [ -n "$serial" ]     && __jwca_kv__ "Serial"      "$serial"
    __jwca_kv__ "Valid from"  "$notbefore"
    __jwca_kv__ "Valid to"    "$notafter"
    [ -n "$mark" ]       && __jwca_kv__ "Expires"     "$mark"
    [ -n "$key" ]        && __jwca_kv__ "Key"         "$key"
    [ -n "$sigalgo" ]    && __jwca_kv__ "Signature"   "$sigalgo"
    [ -n "$fp256" ]      && __jwca_kv__ "SHA-256"     "$fp256"
    [ -n "$fp1" ]        && __jwca_kv__ "SHA-1"       "$fp1"
    [ -n "$ku" ]         && __jwca_kv__ "Key Usage"   "$ku"
    [ -n "$eku" ]        && __jwca_kv__ "Ext Usage"   "$eku"
    [ -n "$bc" ]         && __jwca_kv__ "Constraints" "$bc"
    __jwca_kv__ "CA cert"     "$isca"
    __jwca_kv__ "Self-signed" "$selfsigned"
    echo
    return 0
}


# ---------------------------------------------------------------------------------
# system trust store
# ---------------------------------------------------------------------------------

# One-shot posture X-ray of the system trust store — the flagship glance. Counts what
# is actually trusted (certs in the generated bundle) and where it comes from (package
# vs admin-added local vs disabled), the bundle's path/size/age, how many trusted CAs
# have already EXPIRED, and a freshness/drift check: if any source is newer than the
# generated bundle, the store is stale — the exact `sudo update-ca-certificates` to
# refresh it is printed (never run). Reads only.
jwca_store() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwca_store"
            echo "  Posture of the system trust store: trusted-CA count and sources"
            echo "  (package / local / disabled), bundle path·size·age, expired count,"
            echo "  and a freshness/drift check. Read-only — any refresh command is printed."
            return 0 ;;
    esac
    if ! command -v openssl >/dev/null 2>&1; then
        echo "❌ openssl not available" >&2; return 1
    fi
    [ -r "$_jwca_bundle_" ] || { echo "❌ trust bundle not found/readable: $_jwca_bundle_" >&2; return 1; }

    # grep -c prints the count but EXITS 1 on a zero count, so capture it plainly
    # (assignment ignores the status) — never chain `|| echo 0`, which would double-print.
    local trusted disabled pkg local_n size mtime
    trusted="$(grep -c 'BEGIN CERTIFICATE' "$_jwca_bundle_" 2>/dev/null)"
    if [ -r "$_jwca_conf_" ]; then
        disabled="$(grep -c '^!' "$_jwca_conf_" 2>/dev/null)"
        pkg="$(grep -vcE '^#|^!|^[[:space:]]*$' "$_jwca_conf_" 2>/dev/null)"
    else
        disabled=0; pkg="?"
    fi
    if [ -d "$_jwca_local_" ]; then
        local_n="$(find "$_jwca_local_" -maxdepth 1 -type f -name '*.crt' 2>/dev/null | wc -l)"
    else
        local_n=0
    fi
    size="$(du -h "$_jwca_bundle_" 2>/dev/null | cut -f1)"
    mtime="$(stat -c '%y' "$_jwca_bundle_" 2>/dev/null | cut -d. -f1)"

    local expired
    expired="$(__jwca_bundle_expired__ "$_jwca_bundle_")"

    # Drift: any selection source newer than the generated bundle => stale.
    local newer fresh_mark
    newer="$(find "$_jwca_conf_" "$_jwca_local_" -newer "$_jwca_bundle_" 2>/dev/null | head -1)"
    if [ -n "$newer" ]; then fresh_mark="⚠️ stale — sources changed since last update"; else fresh_mark="✅ up to date"; fi

    echo
    __jwca_h__ "System trust store"
    __jwca_kv__ "Bundle"     "$_jwca_bundle_"
    __jwca_kv__ "Size"       "$size"
    __jwca_kv__ "Modified"   "$mtime"
    echo
    __jwca_kv__ "Trusted CAs" "$trusted"
    __jwca_kv__ "From package" "$pkg"
    __jwca_kv__ "Local (added)" "$local_n"
    __jwca_kv__ "Disabled" "$disabled"
    __jwca_kv__ "Expired" "$([ "${expired:-0}" -gt 0 ] && echo "⚠️ $expired" || echo "✅ 0")"
    echo
    __jwca_kv__ "Freshness" "$fresh_mark"
    if [ -n "$newer" ]; then
        echo
        echo "  # refresh the store (copy-paste — printed, not run):"
        echo "  sudo update-ca-certificates"
    fi
    echo
    return 0
}

# List every trusted CA in the system store, full — a dedicated viewer, so no cap.
# Prefers p11-kit `trust list` (one call; gives the label + trust type + category, so
# a blocklisted/distrusted entry is visible too); falls back to parsing the bundle's
# subjects when `trust` is absent. Reads only.
jwca_list() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwca_list"
            echo "  Every trusted CA in the system store (full list, no cap):"
            echo "  label · trust type · category, via p11-kit 'trust' (bundle-parse fallback)."
            return 0 ;;
    esac

    local tab; tab="$(printf '\t')"
    if command -v trust >/dev/null 2>&1; then
        local body count
        body="$(trust list 2>/dev/null | awk '
            /^pkcs11:/            { label="-"; tr="-"; cat="-"; have=1; next }
            /^[[:space:]]+label:/    { s=$0; sub(/^[[:space:]]*label:[[:space:]]*/,"",s);    label=s }
            /^[[:space:]]+trust:/    { s=$0; sub(/^[[:space:]]*trust:[[:space:]]*/,"",s);    tr=s }
            /^[[:space:]]+category:/ { s=$0; sub(/^[[:space:]]*category:[[:space:]]*/,"",s); cat=s }
            /^[[:space:]]*$/      { if (have) { printf "%s\t%s\t%s\n", label, tr, cat; have=0 } }
            END                   { if (have) printf "%s\t%s\t%s\n", label, tr, cat }
        ' | sort -f)"
        if [ -z "$body" ]; then
            echo "(no anchors reported by 'trust list')"; return 0
        fi
        count="$(printf '%s\n' "$body" | grep -c .)"
        echo
        __jwca_h__ "Trusted CAs ($count)"
        { printf 'LABEL\tTRUST\tCATEGORY\n'; printf '%s\n' "$body"; } | column -t -s "$tab"
        echo
        return 0
    fi

    # Fallback: no p11-kit — enumerate subjects straight from the bundle.
    if ! command -v openssl >/dev/null 2>&1; then
        echo "❌ neither 'trust' nor openssl available" >&2; return 1
    fi
    [ -r "$_jwca_bundle_" ] || { echo "❌ trust bundle not found/readable: $_jwca_bundle_" >&2; return 1; }
    local line buf="" out="" cn subj
    while IFS= read -r line; do
        buf+="$line"$'\n'
        case "$line" in
            *'-----END CERTIFICATE-----'*)
                subj="$(printf '%s' "$buf" | openssl x509 -noout -subject 2>/dev/null | sed -n 's/^subject=//p')"
                buf=""
                [ -z "$subj" ] && continue
                cn="$(__jwca_cn__ "$subj")"
                out+="$cn"$'\n'
                ;;
        esac
    done < "$_jwca_bundle_"
    out="$(printf '%s' "$out" | sort -f)"
    echo
    __jwca_h__ "Trusted CAs ($(printf '%s\n' "$out" | grep -c .)) — bundle subjects"
    printf '%s\n' "$out"
    echo
    return 0
}

# The trust store's deviations from the distro default — the "what has been changed
# here?" view, where a rogue or corporate MITM CA would show up. Two sections: CAs an
# admin added locally (/usr/local/share/ca-certificates), each with CN + CA flag +
# days-to-expiry; and CAs disabled via a '!' line in ca-certificates.conf. Reads only.
jwca_custom() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwca_custom"
            echo "  Deviations from the distro default: admin-added local CAs"
            echo "  (/usr/local/share/ca-certificates) + CAs disabled ('!') in"
            echo "  /etc/ca-certificates.conf. The 'is this store stock?' check. Read-only."
            return 0 ;;
    esac

    echo
    __jwca_h__ "Locally added CAs ($_jwca_local_)"
    if [ ! -d "$_jwca_local_" ]; then
        echo "  (directory absent)"
    else
        local found=0 f cn isca mark bc form der
        local inform=()
        while IFS= read -r f; do
            found=1
            if ! command -v openssl >/dev/null 2>&1; then
                echo "  • $(basename -- "$f")  (openssl unavailable)"; continue
            fi
            form="$(__jwca_certform__ "$f")"
            if [ -z "$form" ]; then
                echo "  • $(basename -- "$f")  (not a readable certificate)"; continue
            fi
            der=0; inform=()
            [ "$form" = "der" ] && { der=1; inform=(-inform DER); }
            cn="$(__jwca_cn__ "$(openssl x509 "${inform[@]}" -in "$f" -noout -subject 2>/dev/null | sed -n 's/^subject=//p')")"
            bc="$(__jwca_x509_ext__ "$f" "$der" basicConstraints)"
            case "$bc" in *CA:TRUE*) isca="CA" ;; *) isca="leaf" ;; esac
            mark="$(__jwca_expiry_mark__ "$(openssl x509 "${inform[@]}" -in "$f" -noout -enddate 2>/dev/null | sed 's/^notAfter=//')")"
            echo "  • $(basename -- "$f")  [$isca] $cn  ${mark}"
        done < <(find "$_jwca_local_" -maxdepth 1 -type f -name '*.crt' 2>/dev/null | sort)
        [ "$found" -eq 0 ] && echo "  (none — trust store matches the distro default)"
    fi

    echo
    __jwca_h__ "Disabled CAs ('!' in $(basename -- "$_jwca_conf_"))"
    if [ ! -r "$_jwca_conf_" ]; then
        echo "  ($(basename -- "$_jwca_conf_") absent/unreadable)"
    else
        local dcount
        dcount="$(grep -c '^!' "$_jwca_conf_" 2>/dev/null)"
        if [ "${dcount:-0}" -eq 0 ]; then
            echo "  (none disabled)"
        else
            echo "  $dcount disabled:"
            grep '^!' "$_jwca_conf_" | sed 's/^!/  • /'
        fi
    fi
    echo
    return 0
}


# ---------------------------------------------------------------------------------
# cross-store
# ---------------------------------------------------------------------------------

# The trust-store fragmentation map — the tool that answers "curl trusts it but Python
# doesn't, why?". A Linux box has SEVERAL independent trust stores; adding a CA to the
# system one does not update the rest. For each, report presence, count/path, and —
# honestly, from what is actually detectable — whether it reads the system store, with
# the KNOWN caveats spelled out (not blanket-asserted). Reads only.
jwca_stores() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: jwca_stores"
            echo "  Map the distinct trust stores on this host (system / p11-kit / NSS /"
            echo "  Java / Python-certifi / Node) — presence, count, and whether each reads"
            echo "  the system store, with the known cross-store gotchas. Read-only."
            return 0 ;;
    esac

    echo
    __jwca_h__ "Cross-store trust map"

    # system (OpenSSL / GnuTLS) — the reference store.
    if [ -r "$_jwca_bundle_" ]; then
        __jwca_kv__ "system" "$(grep -c 'BEGIN CERTIFICATE' "$_jwca_bundle_" 2>/dev/null) CAs · $_jwca_bundle_" 9
    else
        __jwca_kv__ "system" "bundle not found ($_jwca_bundle_)" 9
    fi
    __jwca_kv__ "" "  the reference store — OpenSSL & GnuTLS read this" 9

    # p11-kit — the shared policy layer over the same anchors.
    if command -v trust >/dev/null 2>&1; then
        __jwca_kv__ "p11-kit" "$(trust list 2>/dev/null | grep -c '^pkcs11:') anchors · trust" 9
        __jwca_kv__ "" "  shared policy over the system store (same anchors)" 9
    else
        __jwca_kv__ "p11-kit" "'trust' absent" 9
    fi

    # NSS — Firefox/Chromium user DBs, managed by certutil.
    if command -v certutil >/dev/null 2>&1; then
        __jwca_kv__ "NSS" "certutil present · ~/.pki/nssdb + Firefox profiles" 9
    else
        __jwca_kv__ "NSS" "certutil absent (install libnss3-tools to inspect)" 9
    fi
    __jwca_kv__ "" "  own DB; reads system store only via the p11-kit-trust PKCS#11 module (if loaded)" 9

    # Java — its own cacerts keystore. Shown ONLY when keytool is present: keytool
    # ships with every JRE, so its absence is a reliable proxy for "no Java on this
    # host", and a Java-free box carries no Java row (no standing noise). Where a Java
    # service DOES run, the row returns with a live count + the sync caveat.
    if command -v keytool >/dev/null 2>&1; then
        local jcount
        jcount="$(keytool -list -cacerts -storepass changeit 2>/dev/null | grep -c 'trustedCertEntry')"
        __jwca_kv__ "Java" "${jcount:-?} cacerts entries · keytool" 9
        __jwca_kv__ "" "  separate keystore; ca-certificates-java syncs it from the system store" 9
    fi

    # Python — stdlib ssl uses the system store; requests/certifi use certifi's bundle.
    if command -v python3 >/dev/null 2>&1; then
        local cpath
        cpath="$(python3 -c 'import certifi,sys; sys.stdout.write(certifi.where())' 2>/dev/null)"
        if [ -z "$cpath" ]; then
            __jwca_kv__ "Python" "certifi not installed · stdlib ssl uses the system store" 9
        elif [ "$cpath" = "$_jwca_bundle_" ]; then
            __jwca_kv__ "Python" "certifi → system bundle ✅ (Debian-patched)" 9
        else
            __jwca_kv__ "Python" "certifi → own bundle ⚠️ $cpath" 9
        fi
        __jwca_kv__ "" "  stdlib ssl reads the system store; requests/certifi read the path above (venv pip-certifi may differ)" 9
    else
        __jwca_kv__ "Python" "python3 absent" 9
    fi

    # Node — bundles its own CAs; system CAs come via env/flag, not automatically.
    if command -v node >/dev/null 2>&1; then
        local ncac; if [ -n "${NODE_EXTRA_CA_CERTS:-}" ]; then ncac="set ($NODE_EXTRA_CA_CERTS)"; else ncac="unset"; fi
        __jwca_kv__ "Node" "$(node -v 2>/dev/null) · NODE_EXTRA_CA_CERTS $ncac" 9
        __jwca_kv__ "" "  bundles its own CAs; add the system store via NODE_EXTRA_CA_CERTS or --use-system-ca (Node 22+)" 9
    else
        __jwca_kv__ "Node" "node not on PATH" 9
    fi
    echo
    return 0
}

# Parse `certutil -L` output into "  • <nickname>  [<trust>]  <category>" rows. stdin =
# the listing; $1 = showall (0/1). Trust attrs are the last field (no internal spaces);
# the nickname is the rest (may contain spaces). Header lines are skipped by CONTENT, not
# line number (certutil prints a leading blank line before the header). Default keeps only
# CA-trusted rows (the SSL group has a C/T flag) — the added-anchor signal; --all keeps
# every row, categorised. Its own function so the awk stays out of a nested "$(…)".
__jwca_nss_rows__() {
    JWCA_ALL="$1" awk '
        /Certificate Nickname/ { next }
        /SSL,S\/MIME/          { next }
        /^[[:space:]]*$/       { next }
        {
            trust = $NF
            nick  = $0
            sub(/[[:space:]]+[^[:space:]]+[[:space:]]*$/, "", nick)
            sub(/[[:space:]]+$/, "", nick)
            if (nick == "") next
            split(trust, T, ",")
            isca = (T[1] ~ /[CT]/)
            if (!isca && ENVIRON["JWCA_ALL"] != "1") next
            if (isca)              cat = "trusted CA ⚠️"
            else if (trust ~ /u/)  cat = "user cert"
            else if (trust ~ /P/)  cat = "trusted peer"
            else                   cat = "no trust / cached"
            printf "  • %s  [%s]  %s\n", nick, trust, cat
        }'
}

# What the browser world (NSS) trusts BEYOND the stock Mozilla roots — the one trust
# lane the system-store tools structurally cannot see. Firefox/Chromium/Thunderbird
# ignore the system store for roots: their built-in roots live in libnssckbi.so, NOT in
# the per-profile DB, so listing a DB shows only what was ADDED — imported/corporate
# CAs, interception certs (mitmproxy/Burp/ZAP), and cached exceptions. Default keeps the
# SIGNAL: entries the DB trusts as a CA (an SSL trust flag of C/T) — the browser-lane
# counterpart to jwca_custom; --all shows every entry (incl. cached '/,,'/ peer / user
# certs). Auto-discovers ~/.pki/nssdb + Firefox/Thunderbird profiles, or inspects one DB
# dir if given. Needs certutil (libnss3-tools) to READ; when a DB exists but certutil is
# absent it says so + prints the install. Per current user (per-$HOME DBs). Reads only.
jwca_nss() {
    local showall=0 target="" a
    for a in "$@"; do
        case "$a" in
            -h|--help)
                echo "Usage: jwca_nss [--all] [db-dir]"
                echo "Examples:"
                echo "  jwca_nss                 # discover browser NSS DBs, show ADDED CAs"
                echo "  jwca_nss --all           # every entry (incl. cached / peer / user certs)"
                echo "  jwca_nss ~/.pki/nssdb    # inspect one specific NSS database dir"
                echo
                echo "What NSS databases (Firefox/Chromium/Thunderbird) trust BEYOND the built-in"
                echo "Mozilla roots — the added/imported CAs the system store cannot see. Needs"
                echo "certutil (libnss3-tools) to read. Read-only, scoped to the current user."
                return 0 ;;
            --all) showall=1 ;;
            -*)    echo "❌ unknown flag: $a (see: jwca_nss -h)" >&2; return 1 ;;
            *)     target="$a" ;;
        esac
    done

    local have_certutil=0
    command -v certutil >/dev/null 2>&1 && have_certutil=1

    # Build the DB list as "dir|label" entries.
    local dbs=() db dir label
    if [ -n "$target" ]; then
        { [ -d "$target" ] && { [ -f "$target/cert9.db" ] || [ -f "$target/cert8.db" ]; }; } \
            || { echo "❌ not an NSS database dir (no cert9.db/cert8.db): $target" >&2; return 1; }
        dbs+=("$target|explicit")
    else
        [ -f "$HOME/.pki/nssdb/cert9.db" ] && dbs+=("$HOME/.pki/nssdb|Chromium/Chrome")
        while IFS= read -r db; do
            dir="$(dirname -- "$db")"
            case "$dir" in
                *"/.mozilla/firefox/"*) label="Firefox: $(basename -- "$dir")" ;;
                *"/.thunderbird/"*)     label="Thunderbird: $(basename -- "$dir")" ;;
                *)                      label="$(basename -- "$dir")" ;;
            esac
            dbs+=("$dir|$label")
        done < <(find "$HOME/.mozilla/firefox" "$HOME/.thunderbird" -maxdepth 2 -name 'cert9.db' 2>/dev/null | sort)
    fi

    echo
    if [ "$showall" -eq 1 ]; then __jwca_h__ "NSS trust — all entries"; else __jwca_h__ "NSS trust — added CAs"; fi
    if [ "${#dbs[@]}" -eq 0 ]; then
        echo "  (no NSS databases found — no browser trust on this host)"
        echo
        return 0
    fi

    local out rc rows
    for db in "${dbs[@]}"; do
        dir="${db%%|*}"; label="${db#*|}"
        echo
        echo "  $dir  ($label)"
        if [ "$have_certutil" -eq 0 ]; then
            echo "      certutil absent — sudo apt install libnss3-tools to inspect"
            continue
        fi
        out="$(certutil -L -d "sql:$dir" 2>/dev/null)"; rc=$?
        if [ "$rc" -ne 0 ]; then
            echo "      (could not read — a running browser may hold a lock, or the DB is unreadable)"
            continue
        fi
        rows="$(printf '%s\n' "$out" | __jwca_nss_rows__ "$showall")"
        if [ -z "$rows" ]; then
            if [ "$showall" -eq 1 ]; then echo "      (empty database)"; else echo "      (none added — stock roots only)"; fi
        else
            printf '%s\n' "$rows"
        fi
    done
    echo
    return 0
}
