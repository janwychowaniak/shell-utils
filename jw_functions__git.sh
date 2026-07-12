# shellcheck shell=bash


# ---------------------------------------------------------------------------------
# table of contents
# ---------------------------------------------------------------------------------

# One TOC row: blast-radius marker, padded function name, one-line "soul" tagline.
# printf is byte-width (identical bash/zsh); the marker sits in a fixed slot on
# every row, so the tagline column aligns regardless of emoji width.
__jwgit_toc_row__() {
    printf " - %s %-22s%s\n" "$1" "$2" "$3"
}

jwgit_toc() {
    echo
    echo "   blast radius:  🟢 read-only   🔵 creates   ⚪ state change / transfer   🔴 destructive"
    echo "   (marker = effect on your local repo & working tree; push/pull/fetch = ⚪ transfer)"
    echo
    echo " -----------------------------  repository management"
    __jwgit_toc_row__ 🔵 jwgit_init   "fresh repo; optional --bare"
    __jwgit_toc_row__ 🔵 jwgit_clone  "clone + repo-info summary"
    __jwgit_toc_row__ ⚪ jwgit_remote "list / add / set-url remotes"
    __jwgit_toc_row__ ⚪ jwgit_config "get/set/unset, scope-aware"
    echo
    echo " -----------------------------  branch operations"
    __jwgit_toc_row__ ⚪ jwgit_branch   "list / create / delete / rename"
    __jwgit_toc_row__ ⚪ jwgit_checkout "switch branch / restore file"
    __jwgit_toc_row__ ⚪ jwgit_merge    "merge a branch into HEAD"
    __jwgit_toc_row__ ⚪ jwgit_rebase   "replay commits onto base"
    __jwgit_toc_row__ 🔵 jwgit_tag      "create / annotate / list tags"
    echo
    echo " -----------------------------  staging & commits"
    __jwgit_toc_row__ ⚪ jwgit_add    "stage files; --patch hunks"
    __jwgit_toc_row__ 🔵 jwgit_commit "commit; -m / --amend / --all"
    __jwgit_toc_row__ ⚪ jwgit_stash  "push / pop / list / drop stashes"
    __jwgit_toc_row__ 🔴 jwgit_reset  "soft / mixed / hard reset"
    __jwgit_toc_row__ ⚪ jwgit_revert "new commit that undoes one"
    echo
    echo " -----------------------------  remote operations"
    __jwgit_toc_row__ ⚪ jwgit_push  "push branch to remote"
    __jwgit_toc_row__ ⚪ jwgit_pull  "fetch + integrate remote"
    __jwgit_toc_row__ ⚪ jwgit_fetch "fetch refs, no merge"
    echo
    echo " -----------------------------  history & information"
    __jwgit_toc_row__ 🟢 jwgit_log    "history: graph / oneline / stat"
    __jwgit_toc_row__ 🟢 jwgit_status "branch + ahead/behind + files"
    __jwgit_toc_row__ 🟢 jwgit_diff   "unstaged / cached / range diff"
    __jwgit_toc_row__ 🟢 jwgit_blame  "per-line authorship"
    echo
    echo " -----------------------------  maintenance & cleanup"
    __jwgit_toc_row__ 🔴 jwgit_clean "remove untracked; dry-run first"
    __jwgit_toc_row__ 🔴 jwgit_prune "deep gc + prune unreachable"
    __jwgit_toc_row__ ⚪ jwgit_gc    "safe repack; --deep option"
    echo
    echo " -----------------------------  advanced operations"
    __jwgit_toc_row__ ⚪ jwgit_cherry-pick "apply one commit onto HEAD"
    __jwgit_toc_row__ ⚪ jwgit_bisect      "binary-search a bad commit"
    __jwgit_toc_row__ 🟢 jwgit_reflog      "HEAD movement history"
    echo
}



# ---------------------------------------------------------------------------------
# repository management
# ---------------------------------------------------------------------------------

jwgit_init() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_init [directory] [--bare]"
        echo "Examples:"
        echo "  jwgit_init .                  # Initialize current directory"
        echo "  jwgit_init myproject          # Initialize new directory"
        echo "  jwgit_init myrepo --bare      # Initialize bare repository"
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    # Order-independent parse: --bare toggles bare mode, any other arg is the dir.
    local DIR="."
    local BARE_FLAG=""
    local arg
    for arg in "$@"; do
        case $arg in
            --bare) BARE_FLAG="--bare" ;;
            *)      DIR=$arg ;;
        esac
    done
    
    echo "📁 Initializing Git repository..."
    echo "Directory: $DIR"
    if [ -n "$BARE_FLAG" ]; then
        echo "Type: Bare repository"
    fi
    echo
    
    if [ "$DIR" != "." ] && [ ! -d "$DIR" ]; then
        echo "Creating directory: $DIR"
        mkdir -p "$DIR"
    fi
    
    if [ -n "$BARE_FLAG" ]; then
        git init --bare "$DIR"
    else
        git init "$DIR"
    fi
    local rc=$?

    if [ "$rc" -eq 0 ]; then
        echo "✅ Repository initialized successfully!"
        if [ "$DIR" != "." ]; then
            echo "💡 Run 'cd $DIR' to enter the repository"
        fi
    else
        echo "❌ Failed to initialize repository"
        return 1
    fi
    echo
}


jwgit_clone() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_clone <repository_url> [directory] [options]"
        echo "Examples:"
        echo "  jwgit_clone https://github.com/user/repo.git"
        echo "  jwgit_clone git@github.com:user/repo.git myproject"
        echo "  jwgit_clone https://github.com/user/repo.git --depth 1"
        echo "  jwgit_clone https://github.com/user/repo.git --branch develop"
        echo
        echo "Common options:"
        echo "  --depth N        Create shallow clone with N commits"
        echo "  --branch NAME    Clone specific branch"
        echo "  --single-branch  Clone only one branch"
        echo "  --recursive      Clone with submodules"
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local REPO_URL=$1
    shift
    # Remaining args (optional target dir and/or git-clone options) are forwarded
    # verbatim as "$@" so each token stays separate under both bash and zsh; git
    # clone accepts options after the <url>.
    local DIR
    DIR=$(basename "$REPO_URL" .git)

    echo "📥 Cloning repository..."
    echo "URL: $REPO_URL"
    [ $# -gt 0 ] && echo "Args: $*"
    echo

    # Warn if the default target directory already exists
    if [ -d "$DIR" ]; then
        echo "⚠️  Directory '$DIR' may already exist!"
        echo -n "Continue anyway? [y/N] "
        read -r response
        if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
            echo "Clone cancelled."
            return 1
        fi
    fi

    # Clone — do NOT 'cd' the caller's interactive shell; query via 'git -C'
    if git clone "$REPO_URL" "$@"; then
        echo
        echo "✅ Repository cloned successfully!"
        if [ -d "$DIR" ]; then
            echo "📁 Location: $DIR"
            echo
            __jwgit_h__ "Repository Info"
            __jwgit_kv__ "Remote origin:" "$(git -C "$DIR" remote get-url origin 2>/dev/null || echo 'Not set')"
            __jwgit_kv__ "Current branch:" "$(git -C "$DIR" branch --show-current 2>/dev/null || echo 'Unknown')"
            __jwgit_kv__ "Latest commit:" "$(git -C "$DIR" log -1 --oneline 2>/dev/null || echo 'No commits')"
            __jwgit_kv__ "Total commits:" "$(git -C "$DIR" rev-list --count HEAD 2>/dev/null || echo '0')"
            local branch_count
            branch_count=$(git -C "$DIR" branch -r 2>/dev/null | wc -l)
            __jwgit_kv__ "Remote branches:" "$branch_count"
        else
            echo "💡 cd into your new clone to inspect it"
        fi
    else
        echo "❌ Failed to clone repository"
        return 1
    fi
    echo
}


jwgit_remote() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_remote [add|remove|set-url|show] [name] [url]"
        echo "Examples:"
        echo "  jwgit_remote                           # List all remotes"
        echo "  jwgit_remote show                      # Show detailed remote info"
        echo "  jwgit_remote add upstream <url>        # Add upstream remote"
        echo "  jwgit_remote remove origin             # Remove origin remote"
        echo "  jwgit_remote set-url origin <new_url>  # Change origin URL"
        echo
        echo "Current remotes:"
        if git remote >/dev/null 2>&1; then
            git remote -v | sed 's/^/  /'
        else
            echo "  (not in a git repository)"
        fi
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local ACTION=$1
    local NAME=$2
    local URL=$3
    
    case $ACTION in
        add)
            if [ -z "$NAME" ] || [ -z "$URL" ]; then
                echo "Usage: jwgit_remote add <name> <url>"
                return 1
            fi
            
            echo "Adding remote '$NAME': $URL"
            if git remote add "$NAME" "$URL"; then
                echo "✅ Remote added successfully!"
                echo
                echo "Updated remotes:"
                git remote -v | sed 's/^/  /'
            else
                echo "❌ Failed to add remote"
                return 1
            fi
            ;;
            
        remove|rm)
            if [ -z "$NAME" ]; then
                echo "Usage: jwgit_remote remove <name>"
                echo
                echo "Available remotes:"
                git remote | sed 's/^/  /'
                return 1
            fi
            
            echo "Removing remote '$NAME'..."
            if git remote remove "$NAME"; then
                echo "✅ Remote removed successfully!"
                echo
                echo "Remaining remotes:"
                git remote -v | sed 's/^/  /' || echo "  (no remotes)"
            else
                echo "❌ Failed to remove remote"
                return 1
            fi
            ;;
            
        set-url)
            if [ -z "$NAME" ] || [ -z "$URL" ]; then
                echo "Usage: jwgit_remote set-url <name> <new_url>"
                echo
                echo "Available remotes:"
                git remote -v | sed 's/^/  /'
                return 1
            fi
            
            local old_url
            old_url=$(git remote get-url "$NAME" 2>/dev/null)
            
            echo "Changing remote '$NAME' URL:"
            echo "  From: $old_url"
            echo "  To:   $URL"
            
            if git remote set-url "$NAME" "$URL"; then
                echo "✅ Remote URL updated successfully!"
                echo
                echo "Updated remotes:"
                git remote -v | sed 's/^/  /'
            else
                echo "❌ Failed to update remote URL"
                return 1
            fi
            ;;
            
        show)
            echo "📡 Remote Repository Information"
            echo "=================================================="
            echo
            
            local remotes
            remotes=$(git remote)
            
            if [ -z "$remotes" ]; then
                echo "No remotes configured."
                return 0
            fi
            
            local remote fetch_url push_url branch_count
            while IFS= read -r remote; do
                __jwgit_h__ "Remote: $remote"
                fetch_url=$(git remote get-url "$remote" 2>/dev/null)
                push_url=$(git remote get-url --push "$remote" 2>/dev/null)
                
                echo "Fetch URL: $fetch_url"
                if [ "$push_url" != "$fetch_url" ]; then
                    echo "Push URL:  $push_url"
                fi
                
                # Show remote branches
                echo "Branches:"
                git branch -r | grep "^  $remote/" | sed 's/^/  /' | head -10

                branch_count=$(git branch -r | grep -c "^  $remote/")
                if [ "$branch_count" -gt 10 ]; then
                    echo "  ... and $((branch_count - 10)) more branches"
                fi
                echo
            done <<< "$remotes"
            ;;
            
        *)
            # Default: list remotes
            echo "📡 Git Remotes"
            echo "=================================================="
            echo
            
            if git remote -v | grep -q .; then
                git remote -v | while read -r line; do
                    echo "  $line"
                done
            else
                echo "No remotes configured."
                echo
                echo "💡 Add a remote with: jwgit_remote add <name> <url>"
            fi
            ;;
    esac
    echo
}


jwgit_config() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_config <show|get|set|unset|edit> [args]"
        echo "Examples:"
        echo "  jwgit_config show                        # Layered effective config (all scopes)"
        echo "  jwgit_config show user                   # Only entries matching 'user'"
        echo "  jwgit_config get user.email              # Effective value + where it resolves from"
        echo "  jwgit_config set user.email me@ex.com    # Set (defaults to --local), with confirm"
        echo "  jwgit_config set core.editor vim --global"
        echo "  jwgit_config unset user.email --local    # Remove a key from one scope"
        echo "  jwgit_config edit --global               # Open a scope's file in \$EDITOR"
        echo
        echo "Scopes (low -> high precedence; higher wins):"
        echo "  --system     /etc/gitconfig"
        echo "  --global     ~/.gitconfig"
        echo "  --local      .git/config            (default for set / unset / edit)"
        echo "  --worktree   .git/config.worktree   (needs extensions.worktreeConfig)"
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    # local/worktree scopes and the repo header only make sense inside a repo
    local in_repo=""
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 && in_repo=1

    local ACTION=$1
    shift

    case $ACTION in
        show|list|ls)
            local FILTER=$1   # optional case-insensitive substring filter (key or value)
            echo "⚙️  Effective Git Configuration"
            echo "=================================================="
            echo

            __jwgit_h__ "Repository"
            local repo_root
            repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
            if [ -n "$repo_root" ]; then
                echo "Repository: $(basename "$repo_root")"
                echo "Location:   $repo_root"
            else
                echo "(not in a git repository — showing global / system layers only)"
            fi
            [ -n "$FILTER" ] && echo "Filter:     entries matching '$FILTER'"
            echo

            # Resolve each scope's backing file (shown even when the layer is empty)
            local sys_file glob_file loc_file wt_file wt_on
            sys_file="/etc/gitconfig"
            glob_file=$(git config --global --list --show-origin 2>/dev/null | head -1 | cut -f1 | sed 's/^file://')
            [ -n "$glob_file" ] || glob_file="$HOME/.gitconfig"
            loc_file=$(git rev-parse --git-path config 2>/dev/null)
            wt_file=$(git rev-parse --git-path config.worktree 2>/dev/null)
            wt_on=""
            [ "$(git config --get extensions.worktreeConfig 2>/dev/null)" = "true" ] && wt_on=1

            # Per-layer entry counts
            # Note: with extensions.worktreeConfig disabled, 'git config --worktree'
            # silently FALLS BACK to --local — so the worktree layer is only real
            # when wt_on; otherwise we must not count or dump it (it would duplicate
            # local). System/global empty-notes carry no parens (the helper adds them).
            local s_cnt g_cnt l_cnt w_cnt
            s_cnt=$(git config --system --list 2>/dev/null | wc -l)
            g_cnt=$(git config --global --list 2>/dev/null | wc -l)
            l_cnt=$(git config --local  --list 2>/dev/null | wc -l)
            if [ -n "$wt_on" ]; then
                w_cnt=$(git config --worktree --list 2>/dev/null | wc -l)
            else
                w_cnt=0
            fi

            local loc_note wt_note
            loc_note="none"; wt_note="none"
            [ -n "$wt_on" ] || wt_note="not enabled"
            if [ -z "$in_repo" ]; then
                loc_note="not in a repo"; wt_note="not in a repo"
            fi

            __jwgit_h__ "Layers (low -> high precedence; higher wins)"
            __jwgit_config_layerline__ "🖥" "system  " "$sys_file"  "$s_cnt" "none"
            __jwgit_config_layerline__ "👤" "global  " "$glob_file" "$g_cnt" "none"
            __jwgit_config_layerline__ "📁" "local   " "$loc_file"  "$l_cnt" "$loc_note"
            __jwgit_config_layerline__ "🌿" "worktree" "$wt_file"   "$w_cnt" "$wt_note"
            echo

            # Per-layer contents (printed low -> high); worktree only when truly active
            __jwgit_config_dump__ "system" "🖥" "system  " "$sys_file"  "$FILTER"
            __jwgit_config_dump__ "global" "👤" "global  " "$glob_file" "$FILTER"
            __jwgit_config_dump__ "local"  "📁" "local   " "$loc_file"  "$FILTER"
            [ -n "$wt_on" ] && __jwgit_config_dump__ "worktree" "🌿" "worktree" "$wt_file" "$FILTER"

            # Override map: keys defined in more than one layer (effective = highest).
            # --name-only + sort -u collapses multivar within a scope; awk counts
            # distinct scopes per key; final sort makes the listing deterministic.
            local overrides
            overrides=$(git config --list --show-scope --name-only 2>/dev/null \
                | sort -u \
                | awk -F'\t' '{c[$2]++; s[$2]=s[$2]" "$1} END{for (k in c) if (c[k] > 1) print k"\t"s[k]}' \
                | sort)

            if [ -n "$overrides" ]; then
                __jwgit_h__ "⚠️  Overridden keys (shadowed -> effective)"
                # locals declared once up-front: a bare in-loop 'local' re-prints in zsh
                local okey oscopes effscope sc val
                okey=""; oscopes=""; effscope=""; sc=""; val=""
                while IFS=$'\t' read -r okey oscopes; do
                    [ -n "$okey" ] || continue
                    echo "  $okey"
                    effscope=""
                    for sc in system global local worktree; do
                        case " $oscopes " in *" $sc "*) effscope=$sc ;; esac
                    done
                    for sc in system global local worktree; do
                        case " $oscopes " in
                            *" $sc "*)
                                val=$(git config --"$sc" --get "$okey" 2>/dev/null)
                                if [ "$sc" = "$effscope" ]; then
                                    echo "     $sc : $val   ✅ effective"
                                else
                                    echo "     $sc : $val   (shadowed)"
                                fi
                                ;;
                        esac
                    done
                done <<< "$overrides"
                echo
            else
                __jwgit_h__ "Overrides"
                echo "  (no key is set in more than one layer)"
                echo
            fi
            ;;

        get)
            local KEY=$1
            if [ -z "$KEY" ]; then
                echo "Usage: jwgit_config get <key>"
                echo "Example: jwgit_config get user.email"
                return 1
            fi
            echo "⚙️  $KEY"
            echo "=================================================="

            if ! git config --get "$KEY" >/dev/null 2>&1; then
                # No single effective value: either unset, or a multivar key
                if git config --get-all "$KEY" >/dev/null 2>&1; then
                    echo "  (multivar — multiple values set)"
                    git config --show-scope --get-all "$KEY" 2>/dev/null | sed -e 's/^/  /' -e 's/\t/ : /'
                    echo
                    echo "💡 Edit selectively with: jwgit_config edit <scope>"
                    return 0
                fi
                echo "❌ '$KEY' is not set in any scope"
                echo
                echo "💡 Set it with: jwgit_config set $KEY <value> [--local|--global]"
                return 1
            fi

            local meta eff_scope eff_file eff_val
            meta=$(git config --show-scope --show-origin --get "$KEY" 2>/dev/null)
            eff_scope=$(printf '%s' "$meta" | cut -f1)
            eff_file=$(printf '%s' "$meta" | cut -f2 | sed 's/^file://')
            eff_val=$(git config --get "$KEY" 2>/dev/null)
            echo "  Effective: $eff_val"
            echo "  Source:    $eff_scope ($eff_file)"
            echo
            echo "  Resolution chain (low -> high; higher wins):"
            local sc v wt_on
            sc=""; v=""; wt_on=""
            [ "$(git config --get extensions.worktreeConfig 2>/dev/null)" = "true" ] && wt_on=1
            for sc in system global local worktree; do
                # skip the worktree probe unless it's a real layer: with the
                # extension off, 'git config --worktree --get' falls back to local
                [ "$sc" = "worktree" ] && [ -z "$wt_on" ] && continue
                if v=$(git config --"$sc" --get "$KEY" 2>/dev/null); then
                    if [ "$sc" = "$eff_scope" ]; then
                        echo "     $sc : $v   ✅ effective"
                    else
                        echo "     $sc : $v   (shadowed)"
                    fi
                fi
            done
            echo
            ;;

        set)
            local SCOPE="--local" KEY="" VALUE="" have_key="" have_val=""
            while [ $# -gt 0 ]; do
                case $1 in
                    --local|--global|--system|--worktree) SCOPE=$1 ;;
                    *)
                        if [ -z "$have_key" ]; then
                            KEY=$1; have_key=1
                        elif [ -z "$have_val" ]; then
                            VALUE=$1; have_val=1
                        fi
                        ;;
                esac
                shift
            done
            if [ -z "$have_key" ] || [ -z "$have_val" ]; then
                echo "Usage: jwgit_config set <key> <value> [--local|--global|--system|--worktree]"
                echo "  Scope defaults to --local."
                echo "Examples:"
                echo "  jwgit_config set user.email me@example.com"
                echo "  jwgit_config set core.editor vim --global"
                return 1
            fi
            local scope_name=${SCOPE#--}
            if [ "$SCOPE" = "--worktree" ] && [ "$(git config --get extensions.worktreeConfig 2>/dev/null)" != "true" ]; then
                echo "⚠️  Worktree config not enabled (extensions.worktreeConfig) — git will fall back to --local."
                echo
            fi
            echo "⚙️  Setting $KEY  (scope: $scope_name)"
            echo

            local before eff_before
            before=$(git config "$SCOPE" --get "$KEY" 2>/dev/null)
            eff_before=$(git config --get "$KEY" 2>/dev/null)
            if [ -n "$before" ]; then
                echo "  Current ($scope_name): $before"
            else
                echo "  Current ($scope_name): (unset)"
            fi
            [ -n "$eff_before" ] && echo "  Current effective:    $eff_before"
            echo "  New value:            $VALUE"
            echo

            if [ "$SCOPE" = "--global" ]; then
                echo "⚠️  Writes to GLOBAL config — affects all your repositories."
            elif [ "$SCOPE" = "--system" ]; then
                echo "⚠️  Writes to SYSTEM config — affects all users (usually needs sudo)."
            fi
            echo -n "Proceed? [y/N] "
            read -r response
            if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
                echo "Cancelled"
                return 1
            fi

            if git config "$SCOPE" "$KEY" "$VALUE"; then
                echo "✅ Set $KEY ($scope_name)"
                local eff_after
                eff_after=$(git config --get "$KEY" 2>/dev/null)
                echo "  Effective now: $eff_after"
            else
                echo "❌ Failed to set $KEY"
                return 1
            fi
            ;;

        unset)
            local SCOPE="--local" KEY="" have_key=""
            while [ $# -gt 0 ]; do
                case $1 in
                    --local|--global|--system|--worktree) SCOPE=$1 ;;
                    *) [ -z "$have_key" ] && { KEY=$1; have_key=1; } ;;
                esac
                shift
            done
            if [ -z "$have_key" ]; then
                echo "Usage: jwgit_config unset <key> [--local|--global|--system|--worktree]"
                echo "  Scope defaults to --local."
                return 1
            fi
            local scope_name=${SCOPE#--}
            if [ "$SCOPE" = "--worktree" ] && [ "$(git config --get extensions.worktreeConfig 2>/dev/null)" != "true" ]; then
                echo "⚠️  Worktree config not enabled (extensions.worktreeConfig) — git will fall back to --local."
                echo
            fi

            local cur
            if ! cur=$(git config "$SCOPE" --get "$KEY" 2>/dev/null); then
                # Either not set in this scope, or a multivar (--get refuses those)
                local n
                n=$(git config "$SCOPE" --get-all "$KEY" 2>/dev/null | wc -l)
                if [ "$n" -eq 0 ]; then
                    echo "❌ '$KEY' is not set in $scope_name scope"
                    echo
                    echo "Defined in:"
                    local sc
                    sc=""
                    for sc in system global local worktree; do
                        git config --"$sc" --get "$KEY" >/dev/null 2>&1 && echo "  - $sc"
                    done
                    return 1
                fi
                echo "⚠️  '$KEY' has $n values in $scope_name scope (multivar)."
                echo "💡 Remove all:        git config $SCOPE --unset-all $KEY"
                echo "   Or edit by hand:   jwgit_config edit $SCOPE"
                return 1
            fi

            echo "⚙️  Unsetting $KEY  (scope: $scope_name)"
            echo "  Current value: $cur"
            echo
            echo "⚠️  This removes the key from the $scope_name config."
            echo -n "Proceed? [y/N] "
            read -r response
            if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
                echo "Cancelled"
                return 1
            fi

            if git config "$SCOPE" --unset "$KEY"; then
                echo "✅ Removed $KEY from $scope_name"
                local eff_after
                if eff_after=$(git config --get "$KEY" 2>/dev/null); then
                    echo "  Now effective (from another layer): $eff_after"
                else
                    echo "  No longer set in any layer."
                fi
            else
                echo "❌ Failed to unset $KEY"
                return 1
            fi
            ;;

        edit)
            local SCOPE="--local"
            case $1 in
                --local|--global|--system|--worktree) SCOPE=$1 ;;
                "") ;;
                *)
                    echo "Usage: jwgit_config edit [--local|--global|--system|--worktree]"
                    echo "  Scope defaults to --local."
                    return 1
                    ;;
            esac
            local scope_name=${SCOPE#--}
            echo "⚙️  Opening $scope_name config in your editor..."
            git config "$SCOPE" --edit
            ;;

        *)
            echo "❌ Unknown action: $ACTION"
            echo "Valid actions: show, get, set, unset, edit"
            echo "Run 'jwgit_config' (no args) for usage."
            return 1
            ;;
    esac
    echo
}

__jwgit_config_layerline__() {
    # <emoji> <name> <file> <count> <empty_note>  -> one aligned summary row
    local emoji=$1 name=$2 file=$3 cnt=$4 empty_note=$5 detail
    if [ "$cnt" -eq 1 ]; then
        detail="1 entry"
    elif [ "$cnt" -gt 1 ]; then
        detail="$cnt entries"
    else
        detail="$empty_note"
    fi
    echo "  $emoji $name  $file  ($detail)"
}

__jwgit_config_dump__() {
    # <scope> <emoji> <name> <file> <filter>  -> print a scope's block (skip if empty)
    local scope=$1 emoji=$2 name=$3 file=$4 filter=$5 body
    body=$(git config --"$scope" --list 2>/dev/null)
    [ -n "$body" ] || return 0
    if [ -n "$filter" ]; then
        body=$(printf '%s\n' "$body" | grep -iF -- "$filter")
        [ -n "$body" ] || return 0
    fi
    __jwgit_h__ "$emoji $name  $file"
    # split each 'key=value' on its FIRST '=' only (values may themselves contain '=')
    printf '%s\n' "$body" | sed -e 's/^/  /' -e 's/=/ = /'
    echo
}


# ---------------------------------------------------------------------------------
# branch operations
# ---------------------------------------------------------------------------------

jwgit_branch() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_branch [list|create|delete|rename] [branch_name] [options]"
        echo "Examples:"
        echo "  jwgit_branch                    # List all branches"
        echo "  jwgit_branch list --remote      # List remote branches"
        echo "  jwgit_branch create feature-x   # Create new branch"
        echo "  jwgit_branch delete old-branch  # Delete branch"
        echo "  jwgit_branch rename old new     # Rename branch"
        echo
        echo "Current branches:"
        if git branch >/dev/null 2>&1; then
            git branch --format="%(if)%(HEAD)%(then)* %(else)  %(end)%(refname:short)" | head -10
            local total_branches
            total_branches=$(git branch | wc -l)
            if [ "$total_branches" -gt 10 ]; then
                echo "  ... and $((total_branches - 10)) more branches"
            fi
        else
            echo "  (not in a git repository)"
        fi
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local ACTION=$1
    local BRANCH_NAME=$2
    local OPTION=$3
    
    case $ACTION in
        list|ls)
            echo "🌿 Git Branches"
            echo "=================================================="
            echo
            
            if [ "$BRANCH_NAME" = "--remote" ] || [ "$BRANCH_NAME" = "-r" ]; then
                __jwgit_h__ "Remote Branches"
                git branch -r --format="  %(refname:short)%(if)%(upstream)%(then) -> %(upstream:short)%(end)"
            elif [ "$BRANCH_NAME" = "--all" ] || [ "$BRANCH_NAME" = "-a" ]; then
                __jwgit_h__ "Local Branches"
                git branch --format="%(if)%(HEAD)%(then)* %(else)  %(end)%(refname:short)"
                echo
                __jwgit_h__ "Remote Branches"
                git branch -r --format="  %(refname:short)"
            else
                __jwgit_h__ "Local Branches"
                git branch --format="%(if)%(HEAD)%(then)* %(else)  %(end)%(refname:short)%(if)%(upstream)%(then) -> %(upstream:short)%(end)"
                
                local current_branch
                current_branch=$(git branch --show-current)
                if [ -n "$current_branch" ]; then
                    echo
                    __jwgit_kv__ "Current branch:" "$current_branch"

                    # Show branch info
                    local upstream=""
                    upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
                    if [ -n "$upstream" ]; then
                        __jwgit_kv__ "Upstream:" "$upstream"

                        # Show ahead/behind status
                        local ahead_behind
                        ahead_behind=$(git rev-list --left-right --count "$current_branch...$upstream" 2>/dev/null)
                        if [ -n "$ahead_behind" ]; then
                            local ahead
                            local behind
                            ahead=$(echo "$ahead_behind" | cut -f1)
                            behind=$(echo "$ahead_behind" | cut -f2)

                            if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
                                __jwgit_kv__ "Status:" "$ahead ahead, $behind behind"
                            else
                                __jwgit_kv__ "Status:" "up to date"
                            fi
                        fi
                    else
                        __jwgit_kv__ "Upstream:" "(not set)"
                    fi
                fi
            fi
            ;;
            
        create|new)
            if [ -z "$BRANCH_NAME" ]; then
                echo "Usage: jwgit_branch create <branch_name> [start_point]"
                echo
                echo "Available branches to branch from:"
                git branch --format="  %(refname:short)" | head -10
                return 1
            fi
            
            local START_POINT=${OPTION:-HEAD}
            
            echo "Creating new branch '$BRANCH_NAME' from '$START_POINT'..."
            
            if git branch "$BRANCH_NAME" "$START_POINT"; then
                echo "✅ Branch created successfully!"
                echo
                echo -n "Switch to new branch? [y/N] "
                read -r response
                if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                    git checkout "$BRANCH_NAME"
                    echo "✅ Switched to branch '$BRANCH_NAME'"
                fi
            else
                echo "❌ Failed to create branch"
                return 1
            fi
            ;;
            
        delete|del|rm)
            if [ -z "$BRANCH_NAME" ]; then
                echo "Usage: jwgit_branch delete <branch_name> [--force]"
                echo
                echo "Available branches:"
                git branch --format="  %(refname:short)" | grep -vxF "  $(git branch --show-current)" | head -10
                return 1
            fi
            
            local current_branch
            current_branch=$(git branch --show-current)
            
            if [ "$BRANCH_NAME" = "$current_branch" ]; then
                echo "❌ Cannot delete current branch '$BRANCH_NAME'"
                echo "Switch to another branch first"
                return 1
            fi
            
            echo "Deleting branch '$BRANCH_NAME'..."
            
            if [ "$OPTION" = "--force" ] || [ "$OPTION" = "-f" ]; then
                echo "⚠️  Force deleting branch (may lose unmerged changes)"
                git branch -D "$BRANCH_NAME"
            else
                git branch -d "$BRANCH_NAME"
            fi
            local rc=$?

            if [ "$rc" -eq 0 ]; then
                echo "✅ Branch deleted successfully!"
            else
                echo "❌ Failed to delete branch"
                echo "💡 Use '--force' flag to force delete unmerged branch"
                return 1
            fi
            ;;
            
        rename|mv)
            if [ -z "$BRANCH_NAME" ] || [ -z "$OPTION" ]; then
                echo "Usage: jwgit_branch rename <old_name> <new_name>"
                echo
                echo "Available branches:"
                git branch --format="  %(refname:short)" | head -10
                return 1
            fi
            
            local OLD_NAME=$BRANCH_NAME
            local NEW_NAME=$OPTION
            
            echo "Renaming branch '$OLD_NAME' to '$NEW_NAME'..."
            
            if git branch -m "$OLD_NAME" "$NEW_NAME"; then
                echo "✅ Branch renamed successfully!"
                
                # Update upstream if it exists
                local upstream=""
                upstream=$(git rev-parse --abbrev-ref "$NEW_NAME@{upstream}" 2>/dev/null)
                if [ -n "$upstream" ]; then
                    echo "💡 Consider updating upstream reference if needed"
                fi
            else
                echo "❌ Failed to rename branch"
                return 1
            fi
            ;;
            
        *)
            # Default: list branches (same as 'list' action)
            jwgit_branch list "$@"
            ;;
    esac
    echo
}


jwgit_checkout() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_checkout <branch|commit|file> [options]"
        echo "Examples:"
        echo "  jwgit_checkout main              # Switch to main branch"
        echo "  jwgit_checkout -b feature-x      # Create and switch to new branch"
        echo "  jwgit_checkout abc123            # Switch to specific commit"
        echo "  jwgit_checkout -- file.txt       # Restore file from HEAD"
        echo "  jwgit_checkout HEAD~1 -- file.txt # Restore file from previous commit"
        echo
        echo "Available branches:"
        if git branch >/dev/null 2>&1; then
            git branch --format="  %(refname:short)" | head -10
            echo
            echo "Recent commits:"
            git log --oneline -5 | sed 's/^/  /' 2>/dev/null || echo "  (no commits)"
        else
            echo "  (not in a git repository)"
        fi
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local TARGET=$1
    shift

    # Handle create new branch (-b flag)
    if [ "$TARGET" = "-b" ]; then
        if [ -z "$1" ]; then
            echo "Usage: jwgit_checkout -b <new_branch_name> [start_point]"
            return 1
        fi
        
        local NEW_BRANCH=$1
        local START_POINT=${2:-HEAD}
        
        echo "Creating and switching to new branch '$NEW_BRANCH'..."
        if [ "$START_POINT" != "HEAD" ]; then
            echo "Starting from: $START_POINT"
        fi
        
        if git checkout -b "$NEW_BRANCH" "$START_POINT"; then
            echo "✅ Created and switched to branch '$NEW_BRANCH'"
        else
            echo "❌ Failed to create branch"
            return 1
        fi
        return 0
    fi
    
    # Restore file(s) from HEAD:  jwgit_checkout -- <file>...
    if [ "$TARGET" = "--" ]; then
        if [ $# -eq 0 ]; then
            echo "Usage: jwgit_checkout -- <file_path>"
            echo "       jwgit_checkout <commit> -- <file_path>"
            return 1
        fi

        echo "Restoring from HEAD: $*"
        echo "⚠️  This will discard local changes to the file(s)!"
        echo -n "Continue? [y/N] "
        read -r response

        if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
            if git checkout -- "$@"; then
                echo "✅ File(s) restored successfully"
            else
                echo "❌ Failed to restore file(s)"
                return 1
            fi
        else
            echo "Operation cancelled"
        fi
        return 0
    fi

    # Restore file(s) from a commit:  jwgit_checkout <commit> -- <file>...
    if [ "$1" = "--" ]; then
        shift   # drop the -- separator; remaining "$@" are the paths
        local COMMIT=$TARGET

        echo "Restoring from commit '$COMMIT': $*"
        echo "⚠️  This will discard local changes to the file(s)!"
        echo -n "Continue? [y/N] "
        read -r response

        if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
            if git checkout "$COMMIT" -- "$@"; then
                echo "✅ File(s) restored from commit '$COMMIT'"
            else
                echo "❌ Failed to restore file(s)"
                return 1
            fi
        else
            echo "Operation cancelled"
        fi
        return 0
    fi
    
    # Regular branch/commit checkout
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    
    # Check if target is a branch
    if git show-ref --verify --quiet "refs/heads/$TARGET"; then
        echo "Switching to branch '$TARGET'..."
        if [ -n "$current_branch" ]; then
            echo "From: $current_branch"
        fi
        
        # Check for uncommitted changes
        if ! git diff-index --quiet HEAD --; then
            echo "⚠️  You have uncommitted changes!"
            git status --porcelain | head -5 | sed 's/^/  /'
            echo
            echo -n "Continue anyway? [y/N] "
            read -r response
            if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
                echo "Checkout cancelled"
                echo "💡 Commit or stash your changes first"
                return 1
            fi
        fi
        
        if git checkout "$TARGET"; then
            echo "✅ Switched to branch '$TARGET'"
            
            # Show branch info
            local upstream=""
            upstream=$(git rev-parse --abbrev-ref "$TARGET@{upstream}" 2>/dev/null)
            if [ -n "$upstream" ]; then
                echo "Upstream: $upstream"
            fi
        else
            echo "❌ Failed to switch branch"
            return 1
        fi
        
    # Check if target is a commit hash
    elif git cat-file -e "$TARGET" 2>/dev/null; then
        echo "Switching to commit '$TARGET'..."
        echo "⚠️  This will put you in 'detached HEAD' state"
        echo -n "Continue? [y/N] "
        read -r response
        
        if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
            if git checkout "$TARGET"; then
                echo "✅ Switched to commit '$TARGET'"
                echo "💡 Create a branch if you want to make changes: git checkout -b <branch_name>"
            else
                echo "❌ Failed to checkout commit"
                return 1
            fi
        else
            echo "Checkout cancelled"
        fi
        
    else
        echo "❌ '$TARGET' is not a valid branch or commit"
        echo
        echo "Available branches:"
        git branch --format="  %(refname:short)" | head -5
        echo
        echo "Recent commits:"
        git log --oneline -3 | sed 's/^/  /' 2>/dev/null || echo "  (no commits)"
        return 1
    fi
    echo
}


jwgit_merge() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_merge <branch> [options]"
        echo "Examples:"
        echo "  jwgit_merge feature-branch       # Merge feature branch"
        echo "  jwgit_merge feature --no-ff      # Merge with no fast-forward"
        echo "  jwgit_merge feature --squash     # Squash merge"
        echo "  jwgit_merge --abort              # Abort current merge"
        echo "  jwgit_merge --continue           # Continue after resolving conflicts"
        echo
        echo "Available branches to merge:"
        if git branch >/dev/null 2>&1; then
            local current_branch
            current_branch=$(git branch --show-current)
            git branch --format="  %(refname:short)" | grep -v "^  $current_branch$" | head -10
        else
            echo "  (not in a git repository)"
        fi
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local BRANCH=$1
    shift
    local -a OPTS=("$@")   # remaining args are merge options (array: zsh/bash safe)

    # Handle merge control commands
    case $BRANCH in
        --abort)
            echo "Aborting current merge..."
            if git merge --abort; then
                echo "✅ Merge aborted successfully"
            else
                echo "❌ Failed to abort merge (no merge in progress?)"
                return 1
            fi
            return 0
            ;;
            
        --continue)
            echo "Continuing merge after conflict resolution..."
            
            # Check if there are unresolved conflicts
            if git diff --name-only --diff-filter=U | grep -q .; then
                echo "❌ There are still unresolved conflicts:"
                git diff --name-only --diff-filter=U | sed 's/^/  /'
                echo
                echo "💡 Resolve conflicts and run 'git add <file>' for each resolved file"
                return 1
            fi
            
            if git merge --continue; then
                echo "✅ Merge completed successfully"
            else
                echo "❌ Failed to continue merge"
                return 1
            fi
            return 0
            ;;
    esac
    
    local current_branch
    current_branch=$(git branch --show-current)
    
    if [ -z "$current_branch" ]; then
        echo "❌ Cannot merge in detached HEAD state"
        echo "💡 Switch to a branch first"
        return 1
    fi
    
    # Check if branch exists
    if ! git show-ref --verify --quiet "refs/heads/$BRANCH"; then
        echo "❌ Branch '$BRANCH' does not exist"
        echo
        echo "Available branches:"
        git branch --format="  %(refname:short)" | grep -v "^  $current_branch$" | head -5
        return 1
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        echo "⚠️  You have uncommitted changes!"
        git status --porcelain | head -5 | sed 's/^/  /'
        echo
        echo -n "Commit changes before merge? [y/N] "
        read -r response
        if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
            echo "💡 Please commit your changes first, then retry the merge"
            return 1
        fi
    fi
    
    echo "🔀 Merging branch '$BRANCH' into '$current_branch'"
    echo "=================================================="
    echo
    
    # Show what will be merged
    __jwgit_h__ "Commits to be merged"
    git log --oneline "$current_branch..$BRANCH" | head -5 | sed 's/^/  /'
    local commit_count
    commit_count=$(git rev-list --count "$current_branch..$BRANCH" 2>/dev/null || echo "0")
    echo "Total commits: $commit_count"
    
    if [ "$commit_count" -gt 5 ]; then
        echo "  ... and $((commit_count - 5)) more commits"
    fi
    echo
    
    # Show merge options
    if [ ${#OPTS[@]} -gt 0 ]; then
        echo "Merge options: ${OPTS[*]}"
    else
        echo "Merge type: default (fast-forward if possible)"
    fi
    echo
    
    echo -n "Proceed with merge? [y/N] "
    read -r response
    
    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        echo "Merge cancelled"
        return 1
    fi
    
    # Perform the merge
    echo "Merging..."
    git merge "${OPTS[@]}" "$BRANCH"
    local merge_result=$?
    
    if [ $merge_result -eq 0 ]; then
        echo
        echo "✅ Merge completed successfully!"
        echo
        __jwgit_h__ "Merge Summary"
        __jwgit_kv__ "Merged:" "$BRANCH -> $current_branch"
        __jwgit_kv__ "Latest commit:" "$(git log -1 --oneline)"
        
    else
        echo
        echo "❌ Merge failed due to conflicts!"
        echo
        __jwgit_h__ "Conflicted Files"
        git diff --name-only --diff-filter=U | sed 's/^/  /'
        echo
        echo "💡 To resolve conflicts:"
        echo "   1. Edit the conflicted files"
        echo "   2. Run 'git add <file>' for each resolved file"
        echo "   3. Run 'jwgit_merge --continue' to complete the merge"
        echo "   4. Or run 'jwgit_merge --abort' to cancel the merge"
        
        return 1
    fi
    echo
}


jwgit_rebase() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_rebase <branch|commit> [options]"
        echo "Examples:"
        echo "  jwgit_rebase main                # Rebase current branch onto main"
        echo "  jwgit_rebase main --interactive  # Interactive rebase"
        echo "  jwgit_rebase HEAD~3 -i           # Interactive rebase last 3 commits"
        echo "  jwgit_rebase --continue          # Continue after resolving conflicts"
        echo "  jwgit_rebase --abort             # Abort current rebase"
        echo "  jwgit_rebase --skip              # Skip current commit during rebase"
        echo
        echo "Available branches:"
        if git branch >/dev/null 2>&1; then
            local current_branch
            current_branch=$(git branch --show-current)
            git branch --format="  %(refname:short)" | grep -v "^  $current_branch$" | head -10
        else
            echo "  (not in a git repository)"
        fi
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local TARGET=$1
    shift

    # Handle rebase control commands
    case $TARGET in
        --continue)
            echo "Continuing rebase after conflict resolution..."
            
            # Check if there are unresolved conflicts
            if git diff --name-only --diff-filter=U | grep -q .; then
                echo "❌ There are still unresolved conflicts:"
                git diff --name-only --diff-filter=U | sed 's/^/  /'
                echo
                echo "💡 Resolve conflicts and run 'git add <file>' for each resolved file"
                return 1
            fi
            
            if git rebase --continue; then
                echo "✅ Rebase completed successfully"
            else
                echo "❌ Failed to continue rebase"
                return 1
            fi
            return 0
            ;;
            
        --abort)
            echo "Aborting current rebase..."
            if git rebase --abort; then
                echo "✅ Rebase aborted successfully"
            else
                echo "❌ Failed to abort rebase (no rebase in progress?)"
                return 1
            fi
            return 0
            ;;
            
        --skip)
            echo "Skipping current commit during rebase..."
            if git rebase --skip; then
                echo "✅ Commit skipped, continuing rebase"
            else
                echo "❌ Failed to skip commit"
                return 1
            fi
            return 0
            ;;
    esac
    
    local current_branch
    current_branch=$(git branch --show-current)
    
    if [ -z "$current_branch" ]; then
        echo "❌ Cannot rebase in detached HEAD state"
        echo "💡 Switch to a branch first"
        return 1
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        echo "⚠️  You have uncommitted changes!"
        git status --porcelain | head -5 | sed 's/^/  /'
        echo
        echo "💡 Commit or stash your changes before rebasing"
        return 1
    fi
    
    # Separate the interactive flag (exact match, not substring) from the other
    # options; collect the rest into an array so each token survives bash and zsh.
    local INTERACTIVE=""
    local -a OPTS=()
    local arg
    for arg in "$@"; do
        case $arg in
            -i|--interactive) INTERACTIVE="--interactive" ;;
            *)                OPTS+=("$arg") ;;
        esac
    done
    
    echo "🔄 Rebasing branch '$current_branch' onto '$TARGET'"
    echo "=================================================="
    echo
    
    # Show what will be rebased
    if git merge-base --is-ancestor "$TARGET" HEAD 2>/dev/null; then
        __jwgit_h__ "Commits to be rebased"
        git log --oneline "$TARGET..HEAD" | head -10 | sed 's/^/  /'
        local commit_count
        commit_count=$(git rev-list --count "$TARGET..HEAD" 2>/dev/null || echo "0")
        echo "Total commits: $commit_count"
        
        if [ "$commit_count" -gt 10 ]; then
            echo "  ... and $((commit_count - 10)) more commits"
        fi
    else
        __jwgit_h__ "Rebase Information"
        __jwgit_kv__ "Target:" "$TARGET"
        __jwgit_kv__ "Current branch:" "$current_branch"
        echo "⚠️  This will rewrite commit history!"
    fi
    
    echo
    if [ -n "$INTERACTIVE" ]; then
        echo "Mode: Interactive rebase"
        echo "💡 You'll be able to edit, reorder, or squash commits"
    else
        echo "Mode: Standard rebase"
    fi
    echo
    
    echo -n "Proceed with rebase? [y/N] "
    read -r response
    
    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        echo "Rebase cancelled"
        return 1
    fi
    
    # Perform the rebase
    echo "Rebasing..."
    if [ -n "$INTERACTIVE" ]; then
        git rebase --interactive "${OPTS[@]}" "$TARGET"
    else
        git rebase "${OPTS[@]}" "$TARGET"
    fi
    
    local rebase_result=$?
    
    if [ $rebase_result -eq 0 ]; then
        echo
        echo "✅ Rebase completed successfully!"
        echo
        __jwgit_h__ "Rebase Summary"
        __jwgit_kv__ "Rebased:" "$current_branch onto $TARGET"
        __jwgit_kv__ "Latest commit:" "$(git log -1 --oneline)"
        
    else
        echo
        echo "❌ Rebase failed due to conflicts!"
        echo
        __jwgit_h__ "Conflicted Files"
        git diff --name-only --diff-filter=U | sed 's/^/  /' 2>/dev/null || echo "  (checking conflicts...)"
        echo
        echo "💡 To resolve conflicts:"
        echo "   1. Edit the conflicted files"
        echo "   2. Run 'git add <file>' for each resolved file"
        echo "   3. Run 'jwgit_rebase --continue' to continue the rebase"
        echo "   4. Or run 'jwgit_rebase --abort' to cancel the rebase"
        echo "   5. Or run 'jwgit_rebase --skip' to skip the current commit"
        
        return 1
    fi
    echo
}


jwgit_tag() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_tag [name] [commit] | -a <name> -m <msg> [commit] | -d <name> | list"
        echo "Examples:"
        echo "  jwgit_tag                         # List all tags"
        echo "  jwgit_tag v1.0                    # Lightweight tag at HEAD"
        echo "  jwgit_tag v1.0 abc123             # Lightweight tag at a commit"
        echo "  jwgit_tag -a v1.0 -m \"Release\"    # Annotated tag"
        echo "  jwgit_tag -d v1.0                 # Delete a tag"
        return 0
    fi

    # No args, or an explicit list/ls, lists every tag (annotated, newest-created
    # first). list/ls are kept as guarded aliases on purpose: without them a typed
    # `jwgit_tag list` would fall through to the create branch and tag HEAD "list".
    if [ $# -eq 0 ] || [ "$1" = "list" ] || [ "$1" = "ls" ]; then
        echo "🏷️  Git Tags"
        echo "=================================================="
        if git rev-parse --git-dir >/dev/null 2>&1; then
            local TAGS; TAGS=$(git tag -n --sort=-creatordate)
            if [ -n "$TAGS" ]; then
                printf '%s\n' "$TAGS" | sed 's/^/  /'
            else
                echo "  (no tags)"
            fi
        else
            echo "  (not in a git repository)"
        fi
        return 0
    fi

    case $1 in
        -d|--delete)
            local TAG=$2
            if [ -z "$TAG" ]; then
                echo "Usage: jwgit_tag -d <name>"
                return 1
            fi
            if ! git rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null; then
                echo "❌ Tag '$TAG' does not exist"
                return 1
            fi
            echo "⚠️  This will delete tag '$TAG' ($(git rev-list -n1 --abbrev-commit "$TAG"))"
            echo -n "Continue? [y/N] "
            read -r response
            if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                git tag -d "$TAG"
            else
                echo "Operation cancelled"
            fi
            return 0
            ;;

        -a|--annotate)
            shift
            local NAME="" MSG="" COMMIT=""
            while [ $# -gt 0 ]; do
                case $1 in
                    -m)
                        shift
                        MSG="$1"
                        [ $# -gt 0 ] && shift
                        ;;
                    *)
                        if [ -z "$NAME" ]; then
                            NAME="$1"
                        elif [ -z "$COMMIT" ]; then
                            COMMIT="$1"
                        fi
                        shift
                        ;;
                esac
            done
            if [ -z "$NAME" ]; then
                echo "Usage: jwgit_tag -a <name> -m <msg> [commit]"
                return 1
            fi
            local -a CMD=(tag -a "$NAME")
            [ -n "$MSG" ] && CMD+=(-m "$MSG")
            [ -n "$COMMIT" ] && CMD+=("$COMMIT")
            if git "${CMD[@]}"; then
                echo "✅ Annotated tag '$NAME' created"
            else
                echo "❌ Failed to create tag"
                return 1
            fi
            return 0
            ;;

        *)
            # Lightweight tag: jwgit_tag <name> [commit]
            local NAME=$1
            local COMMIT=$2
            local -a CMD=(tag "$NAME")
            [ -n "$COMMIT" ] && CMD+=("$COMMIT")
            if git "${CMD[@]}"; then
                echo "✅ Tag '$NAME' created at $(git rev-list -n1 --abbrev-commit "$NAME")"
            else
                echo "❌ Failed to create tag"
                return 1
            fi
            return 0
            ;;
    esac
}


# ---------------------------------------------------------------------------------
# staging & commits
# ---------------------------------------------------------------------------------

jwgit_add() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_add <files|pattern> [options]"
        echo "Examples:"
        echo "  jwgit_add .                    # Add all changes"
        echo "  jwgit_add file.txt             # Add specific file"
        echo "  jwgit_add *.js                 # Add all JavaScript files"
        echo "  jwgit_add --patch file.txt     # Interactive staging"
        echo "  jwgit_add --update             # Add only modified files"
        echo
        echo "Current status:"
        if git status --porcelain 2>/dev/null | grep -q .; then
            echo "Modified files:"
            git status --porcelain | grep "^ M\|^M \|^MM" | sed 's/^/  /' | head -10
            echo "Untracked files:"
            git status --porcelain | grep "^??" | sed 's/^/  /' | head -10
        else
            echo "  (no changes to add)"
        fi
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    # Standalone modes (no pathspec needed)
    case $1 in
        --update|-u)
            echo "Adding all modified tracked files..."
            if git add --update; then
                echo "✅ Updated files added to staging area"
                __jwgit_status__
            else
                echo "❌ Failed to add updated files"
                return 1
            fi
            return 0
            ;;

        --all|-A)
            echo "Adding all changes (including untracked files)..."
            echo "⚠️  This will add ALL files in the repository!"
            echo -n "Continue? [y/N] "
            read -r response

            if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                if git add --all; then
                    echo "✅ All changes added to staging area"
                    __jwgit_status__
                else
                    echo "❌ Failed to add all changes"
                    return 1
                fi
            else
                echo "Operation cancelled"
            fi
            return 0
            ;;

        --patch|-p)
            if [ $# -lt 2 ]; then
                echo "Usage: jwgit_add --patch <file>"
                echo
                echo "Modified files available for patch staging:"
                git diff --name-only | sed 's/^/  /' | head -10
                return 1
            fi
            ;;
    esac

    echo "📝 Adding to staging area: $*"
    echo

    # Preview: single existing regular file, or the whole tree ('.')
    if [ $# -eq 1 ] && [ "$1" != "." ] && [[ "$1" != *"*"* ]] && [ -f "$1" ]; then
        __jwgit_h__ "File Status"
        git status --porcelain "$1" | sed 's/^/  /'
        echo
    elif [ "$1" = "." ]; then
        __jwgit_h__ "Changes to be added"
        local modified_count untracked_count
        modified_count=$(git status --porcelain | grep -c "^ M\|^M \|^MM")
        untracked_count=$(git status --porcelain | grep -c "^??")
        echo "Modified files: $modified_count"
        echo "Untracked files: $untracked_count"
        echo
    fi

    # Forward all args (flags + pathspecs) verbatim — "$@" is zsh/bash safe
    if git add "$@"; then
        echo "✅ Files added to staging area successfully!"
        echo
        __jwgit_h__ "Staging Area Status"
        git status --porcelain | grep "^A\|^M\|^D" | sed 's/^/  /' | head -10
        local staged_count
        staged_count=$(git status --porcelain | grep -c "^A\|^M\|^D")
        if [ "$staged_count" -gt 10 ]; then
            echo "  ... and $((staged_count - 10)) more staged files"
        fi
        echo
        echo "💡 Run 'jwgit_commit' to commit these changes"
    else
        echo "❌ Failed to add files"
        return 1
    fi
    echo
}


jwgit_commit() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_commit [message] [options]"
        echo "Examples:"
        echo "  jwgit_commit \"Fix bug in user login\"    # Commit with message"
        echo "  jwgit_commit                              # Open editor for message"
        echo "  jwgit_commit -m \"Quick fix\"             # Commit with inline message"
        echo "  jwgit_commit --amend                      # Amend last commit"
        echo "  jwgit_commit --all -m \"Commit all\"      # Add and commit all changes"
        echo
        echo "Current staging area:"
        if git diff --cached --name-only | grep -q .; then
            echo "Staged files:"
            git diff --cached --name-status | sed 's/^/  /' | head -10
            local staged_count
            staged_count=$(git diff --cached --name-only | wc -l)
            if [ "$staged_count" -gt 10 ]; then
                echo "  ... and $((staged_count - 10)) more files"
            fi
        else
            echo "  (no files staged for commit)"
            echo
            echo "Unstaged changes:"
            git status --porcelain | grep "^ M\|^M " | sed 's/^/  /' | head -5
            echo
            echo "💡 Use 'jwgit_add' to stage files first"
        fi
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local MESSAGE=""
    local -a OPTS=()
    local AMEND=""
    local ALL=""
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            --amend)
                AMEND="--amend"
                shift
                ;;
            --all|-a)
                ALL="--all"
                shift
                ;;
            -m)
                shift
                MESSAGE="$1"
                shift
                ;;
            --message=*)
                MESSAGE="${1#--message=}"
                shift
                ;;
            -*)
                OPTS+=("$1")
                shift
                ;;
            *)
                if [ -z "$MESSAGE" ]; then
                    MESSAGE="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Handle amend
    if [ -n "$AMEND" ]; then
        echo "📝 Amending last commit..."
        
        if [ -n "$MESSAGE" ]; then
            echo "New message: $MESSAGE"
            git commit --amend -m "$MESSAGE"
        else
            echo "Opening editor to modify commit message..."
            git commit --amend
        fi
        local rc=$?

        if [ "$rc" -eq 0 ]; then
            echo "✅ Commit amended successfully!"
            echo "Latest commit: $(git log -1 --oneline)"
        else
            echo "❌ Failed to amend commit"
            return 1
        fi
        return 0
    fi
    
    # Handle commit all
    if [ -n "$ALL" ]; then
        echo "📝 Committing all modified files..."
        
        # Show what will be committed
        echo "Files to be committed:"
        git status --porcelain | grep "^ M\|^M " | sed 's/^/  /' | head -10
        local modified_count
        modified_count=$(git status --porcelain | grep -c "^ M\|^M ")

        if [ "$modified_count" -eq 0 ]; then
            echo "  (no modified files to commit)"
            return 1
        fi
        
        if [ "$modified_count" -gt 10 ]; then
            echo "  ... and $((modified_count - 10)) more files"
        fi
        echo
    fi
    
    # Check if there are staged changes (unless using --all)
    if [ -z "$ALL" ] && ! git diff --cached --quiet; then
        :  # There are staged changes, continue
    elif [ -z "$ALL" ]; then
        echo "❌ No changes staged for commit"
        echo
        echo "Unstaged changes:"
        git status --porcelain | grep "^ M\|^M " | sed 's/^/  /' | head -5
        echo
        echo "💡 Use 'jwgit_add' to stage files, or use '--all' to commit all changes"
        return 1
    fi
    
    echo "📝 Creating commit..."
    if [ -n "$MESSAGE" ]; then
        echo "Message: $MESSAGE"
    else
        echo "Opening editor for commit message..."
    fi
    echo
    
    # Show commit summary
    __jwgit_h__ "Commit Summary"
    if [ -n "$ALL" ]; then
        echo "Type: Commit all modified files"
        git diff --name-status | sed 's/^/  /'
    else
        echo "Type: Commit staged files"
        git diff --cached --name-status | sed 's/^/  /'
    fi
    echo
    
    # Perform the commit — assemble argv as an array so the pass-through
    # options collected from the -*) arm are actually applied (the old
    # builder string was discarded), with safe quoting under bash and zsh.
    local -a CMD=(commit)
    [ -n "$ALL" ] && CMD+=(--all)
    [ -n "$MESSAGE" ] && CMD+=(-m "$MESSAGE")
    CMD+=("${OPTS[@]}")

    git "${CMD[@]}"
    local commit_result=$?
    
    if [ $commit_result -eq 0 ]; then
        echo
        echo "✅ Commit created successfully!"
        echo
        __jwgit_h__ "Commit Information"
        __jwgit_kv__ "Commit:" "$(git log -1 --oneline)"
        __jwgit_kv__ "Author:" "$(git log -1 --format='%an <%ae>')"
        __jwgit_kv__ "Date:" "$(git log -1 --format='%ad' --date=format:'%Y-%m-%d %H:%M:%S')"

        # Show files changed
        local files_changed
        files_changed=$(git diff --name-only HEAD~1 HEAD | wc -l)
        __jwgit_kv__ "Files changed:" "$files_changed"

        # Show branch status
        local current_branch
        current_branch=$(git branch --show-current)
        if [ -n "$current_branch" ]; then
            __jwgit_kv__ "Branch:" "$current_branch"

            # Show ahead/behind status if upstream exists
            local upstream=""
            upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
            if [ -n "$upstream" ]; then
                local ahead_behind
                ahead_behind=$(git rev-list --left-right --count "$current_branch...$upstream" 2>/dev/null)
                if [ -n "$ahead_behind" ]; then
                    local ahead
                    local behind
                    ahead=$(echo "$ahead_behind" | cut -f1)
                    behind=$(echo "$ahead_behind" | cut -f2)
                    __jwgit_kv__ "Status:" "$ahead ahead, $behind behind $upstream"
                fi
            fi
        fi
        
    else
        echo "❌ Commit failed!"
        echo "💡 Check your commit message and staged files"
        return 1
    fi
    echo
}


jwgit_stash() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_stash [push|pop|list|show|drop|clear] [options]"
        echo "Examples:"
        echo "  jwgit_stash                        # Stash current changes"
        echo "  jwgit_stash push -m \"WIP feature\" # Stash with message"
        echo "  jwgit_stash pop                    # Apply and remove latest stash"
        echo "  jwgit_stash list                   # List all stashes"
        echo "  jwgit_stash show stash@{0}         # Show stash contents"
        echo "  jwgit_stash drop stash@{1}         # Delete specific stash"
        echo "  jwgit_stash clear                  # Delete all stashes"
        echo
        echo "Current changes:"
        if git status --porcelain | grep -q .; then
            git status --porcelain | head -10 | sed 's/^/  /'
            local change_count
            change_count=$(git status --porcelain | wc -l)
            if [ "$change_count" -gt 10 ]; then
                echo "  ... and $((change_count - 10)) more changes"
            fi
        else
            echo "  (no changes to stash)"
        fi
        echo
        echo "Existing stashes:"
        git stash list | head -5 | sed 's/^/  /' 2>/dev/null || echo "  (no stashes)"
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local ACTION=$1
    shift

    case $ACTION in
        push|save)
            echo "📦 Stashing current changes..."
            
            # Check if there are changes to stash
            if ! git status --porcelain | grep -q .; then
                echo "❌ No changes to stash"
                return 1
            fi
            
            # Show what will be stashed
            echo "Changes to be stashed:"
            git status --porcelain | head -10 | sed 's/^/  /'
            local change_count
            change_count=$(git status --porcelain | wc -l)
            if [ "$change_count" -gt 10 ]; then
                echo "  ... and $((change_count - 10)) more changes"
            fi
            echo
            
            # Perform stash (forward args verbatim — zsh/bash safe)
            if git stash push "$@"; then
                echo "✅ Changes stashed successfully!"
                echo "Latest stash: $(git stash list | head -1)"
                echo
                echo "Working directory is now clean:"
                git status --short
            else
                echo "❌ Failed to stash changes"
                return 1
            fi
            ;;
            
        pop)
            echo "📦 Applying and removing latest stash..."
            
            # Check if there are stashes
            if ! git stash list | grep -q .; then
                echo "❌ No stashes to pop"
                return 1
            fi
            
            # Show which stash will be popped
            echo "Stash to be applied:"
            echo "  $(git stash list | head -1)"
            echo
            
            # Check for conflicts with current changes
            if git status --porcelain | grep -q .; then
                echo "⚠️  You have uncommitted changes!"
                git status --porcelain | head -5 | sed 's/^/  /'
                echo
                echo -n "Continue anyway? [y/N] "
                read -r response
                if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
                    echo "Stash pop cancelled"
                    return 1
                fi
            fi
            
            # Apply the stash (forward args verbatim — zsh/bash safe)
            if git stash pop "$@"; then
                echo "✅ Stash applied and removed successfully!"
                echo
                echo "Current status:"
                git status --short
            else
                echo "❌ Failed to apply stash (conflicts?)"
                echo "💡 Resolve conflicts and commit, or use 'git stash drop' to discard"
                return 1
            fi
            ;;
            
        apply)
            local STASH_REF=$1
            [ -n "$STASH_REF" ] || STASH_REF='stash@{0}'
            
            echo "📦 Applying stash (keeping in stash list)..."
            
            # Check if stash exists
            if ! git stash list | grep -qF "$STASH_REF"; then
                echo "❌ Stash '$STASH_REF' not found"
                echo
                echo "Available stashes:"
                git stash list | head -5 | sed 's/^/  /'
                return 1
            fi
            
            echo "Applying: $(git stash list | grep -F "$STASH_REF")"
            echo
            
            # Apply the stash
            if git stash apply "$STASH_REF"; then
                echo "✅ Stash applied successfully!"
                echo "💡 Stash is still saved in stash list"
                echo
                echo "Current status:"
                git status --short
            else
                echo "❌ Failed to apply stash"
                return 1
            fi
            ;;
            
        list|ls)
            echo "📦 Git Stashes"
            echo "=================================================="
            echo
            
            if git stash list | grep -q .; then
                git stash list | while IFS= read -r stash_line; do
                    echo "  $stash_line"
                done
                echo
                local stash_count
                stash_count=$(git stash list | wc -l)
                echo "Total stashes: $stash_count"
            else
                echo "No stashes found."
            fi
            ;;
            
        show)
            local STASH_REF=$1
            [ -n "$STASH_REF" ] || STASH_REF='stash@{0}'
            
            echo "📦 Stash Contents: $STASH_REF"
            echo "=================================================="
            echo
            
            # Check if stash exists
            if ! git stash list | grep -qF "$STASH_REF"; then
                echo "❌ Stash '$STASH_REF' not found"
                echo
                echo "Available stashes:"
                git stash list | head -5 | sed 's/^/  /'
                return 1
            fi
            
            # Show stash information
            __jwgit_h__ "Stash Info"
            git stash list | grep -F "$STASH_REF" | sed 's/^/  /'
            echo
            
            __jwgit_h__ "Changed Files"
            git stash show --name-status "$STASH_REF" | sed 's/^/  /'
            echo
            
            __jwgit_h__ "Diff Summary"
            git stash show --stat "$STASH_REF"
            echo
            
            echo "💡 Use 'git stash show -p $STASH_REF' to see full diff"
            ;;
            
        drop)
            local STASH_REF=$1
            [ -n "$STASH_REF" ] || STASH_REF='stash@{0}'
            
            echo "📦 Dropping stash: $STASH_REF"
            
            # Check if stash exists
            if ! git stash list | grep -qF "$STASH_REF"; then
                echo "❌ Stash '$STASH_REF' not found"
                echo
                echo "Available stashes:"
                git stash list | head -5 | sed 's/^/  /'
                return 1
            fi
            
            # Show which stash will be dropped
            echo "Stash to be dropped:"
            echo "  $(git stash list | grep -F "$STASH_REF")"
            echo
            echo "⚠️  This action cannot be undone!"
            echo -n "Continue? [y/N] "
            read -r response
            
            if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                if git stash drop "$STASH_REF"; then
                    echo "✅ Stash dropped successfully!"
                else
                    echo "❌ Failed to drop stash"
                    return 1
                fi
            else
                echo "Operation cancelled"
            fi
            ;;
            
        clear)
            echo "📦 Clearing all stashes..."
            
            local stash_count
            stash_count=$(git stash list | wc -l)
            
            if [ "$stash_count" -eq 0 ]; then
                echo "No stashes to clear."
                return 0
            fi
            
            echo "This will delete $stash_count stashes:"
            git stash list | head -5 | sed 's/^/  /'
            if [ "$stash_count" -gt 5 ]; then
                echo "  ... and $((stash_count - 5)) more stashes"
            fi
            echo
            echo "⚠️  This action cannot be undone!"
            echo -n "Continue? [y/N] "
            read -r response
            
            if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                if git stash clear; then
                    echo "✅ All stashes cleared successfully!"
                else
                    echo "❌ Failed to clear stashes"
                    return 1
                fi
            else
                echo "Operation cancelled"
            fi
            ;;
            
        *)
            # Default: treat the whole invocation as 'push' (forward verbatim)
            jwgit_stash push "$ACTION" "$@"
            ;;
    esac
    echo
}


jwgit_reset() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_reset [--soft|--mixed|--hard] [commit] [files]"
        echo "Examples:"
        echo "  jwgit_reset                    # Unstage all files (mixed reset to HEAD)"
        echo "  jwgit_reset --soft HEAD~1      # Undo last commit, keep changes staged"
        echo "  jwgit_reset --mixed HEAD~1     # Undo last commit, unstage changes"
        echo "  jwgit_reset --hard HEAD~1      # Undo last commit, discard all changes"
        echo "  jwgit_reset file.txt           # Unstage specific file"
        echo "  jwgit_reset --hard origin/main # Reset to remote branch state"
        echo
        echo "⚠️  WARNING: --hard reset will permanently delete uncommitted changes!"
        echo
        echo "Current status:"
        if git status --porcelain | grep -q .; then
            echo "Staged files:"
            git status --porcelain | grep "^[MADRC]" | sed 's/^/  /' | head -5
            echo "Modified files:"
            git status --porcelain | grep "^ [MD]" | sed 's/^/  /' | head -5
        else
            echo "  (working directory clean)"
        fi
        echo
        echo "Recent commits:"
        git log --oneline -5 | sed 's/^/  /' 2>/dev/null || echo "  (no commits)"
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local RESET_TYPE=""
    local TARGET="HEAD"
    local -a FILES=()
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            --soft|--mixed|--hard)
                RESET_TYPE="$1"
                shift
                ;;
            -*)
                echo "❌ Unknown option: $1"
                return 1
                ;;
            *)
                if [ -z "$TARGET" ] || [ "$TARGET" = "HEAD" ]; then
                    # Check if it's a file or commit
                    if [ -f "$1" ] || git ls-files --error-unmatch "$1" >/dev/null 2>&1; then
                        FILES+=("$1")
                        TARGET="HEAD"  # Reset target back to HEAD for file reset
                    else
                        TARGET="$1"
                    fi
                else
                    FILES+=("$1")
                fi
                shift
                ;;
        esac
    done
    
    # Handle file-specific reset
    if [ ${#FILES[@]} -gt 0 ]; then
        echo "📝 Resetting files (target: $TARGET)..."
        echo "Files: ${FILES[*]}"
        echo

        # Show current status of files
        echo "Current status:"
        local file
        for file in "${FILES[@]}"; do
            git status --porcelain "$file" | sed 's/^/  /'
        done
        echo

        # Path reset to the requested commit (HEAD by default), array-safe
        if git reset "$TARGET" -- "${FILES[@]}"; then
            echo "✅ Files reset successfully!"
            echo
            echo "Updated status:"
            for file in "${FILES[@]}"; do
                git status --porcelain "$file" | sed 's/^/  /'
            done
        else
            echo "❌ Failed to reset files"
            return 1
        fi
        return 0
    fi
    
    # Handle commit reset
    echo "🔄 Resetting to commit: $TARGET"
    echo "Reset type: ${RESET_TYPE:-mixed (default)}"
    echo
    
    # Validate target commit
    if ! git rev-parse --verify "$TARGET" >/dev/null 2>&1; then
        echo "❌ Invalid commit: $TARGET"
        echo
        echo "Recent commits:"
        git log --oneline -5 | sed 's/^/  /'
        return 1
    fi
    
    # Show what will happen
    __jwgit_h__ "Reset Information"
    __jwgit_kv__ "Current HEAD:" "$(git rev-parse --short HEAD) ($(git log -1 --oneline))"
    __jwgit_kv__ "Reset target:" "$(git rev-parse --short "$TARGET") ($(git log -1 --oneline "$TARGET"))"
    echo
    
    # Show commits that will be affected
    if [ "$TARGET" != "HEAD" ]; then
        local commits_affected
        commits_affected=$(git rev-list --count "$TARGET"..HEAD 2>/dev/null || echo "0")
        
        if [ "$commits_affected" -gt 0 ]; then
            echo "Commits that will be reset:"
            git log --oneline "$TARGET"..HEAD | sed 's/^/  /' | head -5
            if [ "$commits_affected" -gt 5 ]; then
                echo "  ... and $((commits_affected - 5)) more commits"
            fi
            echo
        fi
    fi
    
    # Explain what each reset type does
    case $RESET_TYPE in
        --soft)
            echo "Soft reset will:"
            echo "  ✅ Move HEAD to target commit"
            echo "  ✅ Keep changes staged"
            echo "  ✅ Keep working directory unchanged"
            ;;
        --mixed|"")
            echo "Mixed reset will:"
            echo "  ✅ Move HEAD to target commit"
            echo "  ⚠️  Unstage all changes"
            echo "  ✅ Keep working directory unchanged"
            ;;
        --hard)
            echo "Hard reset will:"
            echo "  ⚠️  Move HEAD to target commit"
            echo "  ⚠️  Discard all staged changes"
            echo "  ⚠️  PERMANENTLY DELETE all uncommitted changes"
            echo
            echo "🚨 DANGER: This will permanently delete:"
            if git status --porcelain | grep -q .; then
                git status --porcelain | sed 's/^/    /' | head -10
            else
                echo "    (no uncommitted changes)"
            fi
            ;;
    esac
    
    echo
    echo -n "Proceed with reset? [y/N] "
    read -r response
    
    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        echo "Reset cancelled"
        return 1
    fi
    
    # Perform the reset
    echo "Performing reset..."
    if [ -n "$RESET_TYPE" ]; then
        git reset "$RESET_TYPE" "$TARGET"
    else
        git reset "$TARGET"
    fi
    
    local reset_result=$?
    
    if [ $reset_result -eq 0 ]; then
        echo
        echo "✅ Reset completed successfully!"
        echo
        __jwgit_h__ "Reset Summary"
        echo "HEAD is now at: $(git rev-parse --short HEAD) ($(git log -1 --oneline))"
        
        case $RESET_TYPE in
            --soft)
                echo "Changes are still staged and ready to commit"
                ;;
            --mixed|"")
                echo "Changes are unstaged but preserved in working directory"
                ;;
            --hard)
                echo "Working directory and staging area are clean"
                ;;
        esac
        
        echo
        echo "Current status:"
        git status --short
        
    else
        echo "❌ Reset failed!"
        return 1
    fi
    echo
}


jwgit_revert() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_revert <commit> [options] | --continue | --abort | --skip"
        echo "Examples:"
        echo "  jwgit_revert abc123               # Create a commit that undoes abc123"
        echo "  jwgit_revert --no-commit abc123   # Stage the revert without committing"
        echo "  jwgit_revert --continue           # Continue after resolving conflicts"
        echo "  jwgit_revert --abort              # Abort the in-progress revert"
        echo
        echo "Recent commits:"
        git log --oneline -10 2>/dev/null | sed 's/^/  /' || echo "  (no commits)"
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    # Control commands
    case $1 in
        --continue)
            if git diff --name-only --diff-filter=U | grep -q .; then
                echo "❌ Unresolved conflicts remain:"
                git diff --name-only --diff-filter=U | sed 's/^/  /'
                return 1
            fi
            if git revert --continue; then
                echo "✅ Revert completed"
            else
                echo "❌ Failed to continue revert"
                return 1
            fi
            return 0
            ;;
        --abort)
            if git revert --abort; then echo "✅ Revert aborted"; else echo "❌ Failed to abort revert"; return 1; fi
            return 0
            ;;
        --skip)
            if git revert --skip; then echo "✅ Commit skipped"; else echo "❌ Failed to skip"; return 1; fi
            return 0
            ;;
    esac

    # Forward all args (commit + options) verbatim — "$@" is zsh/bash safe
    echo "↩️  Reverting: $*"
    echo
    if git revert "$@"; then
        echo
        echo "✅ Revert completed successfully!"
        echo "Latest commit: $(git log -1 --oneline)"
    else
        echo
        echo "❌ Revert failed (conflicts?)"
        echo "💡 Resolve conflicts, then 'jwgit_revert --continue' (or --abort)"
        return 1
    fi
    echo
}


# ---------------------------------------------------------------------------------
# remote operations
# ---------------------------------------------------------------------------------

jwgit_push() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_push [remote] [branch] [options]"
        echo "Examples:"
        echo "  jwgit_push                     # Push current branch to upstream"
        echo "  jwgit_push origin main         # Push main branch to origin"
        echo "  jwgit_push origin --all        # Push all branches"
        echo "  jwgit_push origin --tags       # Push all tags"
        echo "  jwgit_push --set-upstream origin feature  # Set upstream and push"
        echo "  jwgit_push --force-with-lease  # Force push safely"
        echo
        echo "Current branch info:"
        local current_branch
        current_branch=$(git branch --show-current 2>/dev/null)
        if [ -n "$current_branch" ]; then
            echo "Branch: $current_branch"
            
            local upstream=""
            upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
            if [ -n "$upstream" ]; then
                echo "Upstream: $upstream"
                
                # Show ahead/behind status
                local ahead_behind
                ahead_behind=$(git rev-list --left-right --count "$current_branch...$upstream" 2>/dev/null)
                if [ -n "$ahead_behind" ]; then
                    local ahead
                    local behind
                    ahead=$(echo "$ahead_behind" | cut -f1)
                    behind=$(echo "$ahead_behind" | cut -f2)
                    echo "Status: $ahead ahead, $behind behind"
                fi
            else
                echo "Upstream: (not set)"
            fi
        else
            echo "  (not on any branch)"
        fi
        echo
        echo "Available remotes:"
        git remote -v | sed 's/^/  /' || echo "  (no remotes configured)"
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local REMOTE=""
    local BRANCH=""
    local -a OPTS=()
    local SET_UPSTREAM=""
    local FORCE=""
    local HAS_ALL_TAGS=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            --set-upstream|-u)
                SET_UPSTREAM="--set-upstream"
                shift
                ;;
            --force-with-lease)
                FORCE="--force-with-lease"
                shift
                ;;
            --force|-f)
                FORCE="--force"
                shift
                ;;
            --all|--tags)
                OPTS+=("$1")
                HAS_ALL_TAGS=1
                shift
                ;;
            -*)
                OPTS+=("$1")
                shift
                ;;
            *)
                if [ -z "$REMOTE" ]; then
                    REMOTE="$1"
                elif [ -z "$BRANCH" ]; then
                    BRANCH="$1"
                else
                    OPTS+=("$1")
                fi
                shift
                ;;
        esac
    done
    
    # Set defaults
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    
    if [ -z "$REMOTE" ]; then
        # Try to get upstream remote
        local upstream=""
        upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
        if [ -n "$upstream" ]; then
            REMOTE=$(echo "$upstream" | cut -d'/' -f1)
        else
            REMOTE="origin"
        fi
    fi
    
    if [ -z "$BRANCH" ] && [ -z "$HAS_ALL_TAGS" ]; then
        BRANCH="$current_branch"
    fi
    
    echo "📤 Pushing to remote repository..."
    __jwgit_kv__ "Remote:" "$REMOTE"
    if [ -n "$BRANCH" ]; then
        __jwgit_kv__ "Branch:" "$BRANCH"
    fi
    if [ ${#OPTS[@]} -gt 0 ]; then
        __jwgit_kv__ "Options:" "${OPTS[*]}"
    fi
    if [ -n "$SET_UPSTREAM" ]; then
        __jwgit_kv__ "Setting upstream:" "$REMOTE/$BRANCH"
    fi
    if [ -n "$FORCE" ]; then
        __jwgit_kv__ "Force push:" "$FORCE"
    fi
    echo
    
    # Validate remote
    if ! git remote | grep -qxF "$REMOTE"; then
        echo "❌ Remote '$REMOTE' not found"
        echo
        echo "Available remotes:"
        git remote | sed 's/^/  /'
        return 1
    fi
    
    # Check if branch exists (for non-special pushes)
    if [ -n "$BRANCH" ] && [ -z "$HAS_ALL_TAGS" ]; then
        if [ "$BRANCH" != "$current_branch" ] && ! git show-ref --verify --quiet "refs/heads/$BRANCH"; then
            echo "❌ Branch '$BRANCH' does not exist"
            echo
            echo "Available branches:"
            git branch --format="  %(refname:short)" | head -10
            return 1
        fi
    fi
    
    # Show what will be pushed
    if [ -n "$BRANCH" ] && [ -z "$HAS_ALL_TAGS" ]; then
        __jwgit_h__ "Commits to Push"
        
        # Check if remote branch exists
        if git show-ref --verify --quiet "refs/remotes/$REMOTE/$BRANCH"; then
            local commits_to_push
            commits_to_push=$(git rev-list --count "$REMOTE/$BRANCH..$BRANCH" 2>/dev/null || echo "0")
            
            if [ "$commits_to_push" -gt 0 ]; then
                echo "New commits to push: $commits_to_push"
                git log --oneline "$REMOTE/$BRANCH..$BRANCH" | head -5 | sed 's/^/  /'
                if [ "$commits_to_push" -gt 5 ]; then
                    echo "  ... and $((commits_to_push - 5)) more commits"
                fi
            else
                echo "Branch is up to date with remote"
            fi
        else
            echo "New branch - all commits will be pushed:"
            git log --oneline "$BRANCH" | head -5 | sed 's/^/  /' 2>/dev/null || echo "  (no commits)"
            local total_commits
            total_commits=$(git rev-list --count "$BRANCH" 2>/dev/null || echo "0")
            if [ "$total_commits" -gt 5 ]; then
                echo "  ... and $((total_commits - 5)) more commits"
            fi
        fi
        echo
    fi
    
    # Warning for force push
    if [ -n "$FORCE" ]; then
        echo "⚠️  WARNING: Force push will rewrite remote history!"
        echo "This may affect other collaborators."
        echo
        echo -n "Continue with force push? [y/N] "
        read -r response
        if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
            echo "Push cancelled"
            return 1
        fi
    fi
    
    # Build the push argv as an array — no eval, so remote/branch values are
    # never re-parsed by the shell, and tokens stay separate under bash and zsh
    local -a CMD=(push)
    [ -n "$SET_UPSTREAM" ] && CMD+=(--set-upstream)
    [ -n "$FORCE" ] && CMD+=("$FORCE")
    CMD+=("${OPTS[@]}")
    CMD+=("$REMOTE")
    if [ -n "$BRANCH" ] && [ -z "$HAS_ALL_TAGS" ]; then
        CMD+=("$BRANCH")
    fi

    # Execute push
    echo "Pushing..."
    git "${CMD[@]}"
    local push_result=$?
    
    if [ $push_result -eq 0 ]; then
        echo
        echo "✅ Push completed successfully!"
        echo
        __jwgit_h__ "Push Summary"
        __jwgit_kv__ "Remote:" "$REMOTE"
        if [ -n "$BRANCH" ]; then
            __jwgit_kv__ "Branch:" "$BRANCH"

            # Update upstream info
            if [ -n "$SET_UPSTREAM" ]; then
                __jwgit_kv__ "Upstream set:" "$REMOTE/$BRANCH"
            fi

            # Show final status
            local upstream=""
            upstream=$(git rev-parse --abbrev-ref "$BRANCH@{upstream}" 2>/dev/null)
            if [ -n "$upstream" ]; then
                __jwgit_kv__ "Status:" "up to date with $upstream"
            fi
        fi
        
    else
        echo
        echo "❌ Push failed!"
        echo
        echo "Common solutions:"
        echo "  - Pull latest changes: jwgit_pull"
        echo "  - Force push (dangerous): jwgit_push --force-with-lease"
        echo "  - Set upstream: jwgit_push --set-upstream $REMOTE $BRANCH"
        
        return 1
    fi
    echo
}


jwgit_pull() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_pull [remote] [branch] [options]"
        echo "Examples:"
        echo "  jwgit_pull                     # Pull current branch from upstream"
        echo "  jwgit_pull origin main         # Pull main branch from origin"
        echo "  jwgit_pull --rebase            # Pull with rebase instead of merge"
        echo "  jwgit_pull --no-commit         # Pull without auto-commit"
        echo "  jwgit_pull --all               # Fetch all remotes"
        echo
        echo "Current branch info:"
        local current_branch
        current_branch=$(git branch --show-current 2>/dev/null)
        if [ -n "$current_branch" ]; then
            echo "Branch: $current_branch"
            
            local upstream=""
            upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
            if [ -n "$upstream" ]; then
                echo "Upstream: $upstream"
                
                # Show ahead/behind status
                local ahead_behind
                ahead_behind=$(git rev-list --left-right --count "$current_branch...$upstream" 2>/dev/null)
                if [ -n "$ahead_behind" ]; then
                    local ahead
                    local behind
                    ahead=$(echo "$ahead_behind" | cut -f1)
                    behind=$(echo "$ahead_behind" | cut -f2)
                    echo "Status: $ahead ahead, $behind behind"
                    
                    if [ "$behind" -eq 0 ]; then
                        echo "💡 Branch is up to date"
                    fi
                fi
            else
                echo "Upstream: (not set)"
                echo "💡 Set upstream with: git branch --set-upstream-to=origin/$current_branch"
            fi
        else
            echo "  (not on any branch)"
        fi
        echo
        echo "Available remotes:"
        git remote -v | sed 's/^/  /' || echo "  (no remotes configured)"
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local REMOTE=""
    local BRANCH=""
    local -a OPTS=()
    local REBASE=""
    local HAS_ALL=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            --rebase|-r)
                REBASE="--rebase"
                shift
                ;;
            --all)
                OPTS+=("$1")
                HAS_ALL=1
                shift
                ;;
            -*)
                OPTS+=("$1")
                shift
                ;;
            *)
                if [ -z "$REMOTE" ]; then
                    REMOTE="$1"
                elif [ -z "$BRANCH" ]; then
                    BRANCH="$1"
                else
                    OPTS+=("$1")
                fi
                shift
                ;;
        esac
    done
    
    # Set defaults
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    
    if [ -z "$REMOTE" ] && [ -z "$BRANCH" ]; then
        # Use upstream if available
        local upstream=""
        upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
        if [ -n "$upstream" ]; then
            REMOTE=$(echo "$upstream" | cut -d'/' -f1)
            BRANCH=$(echo "$upstream" | cut -d'/' -f2-)
        else
            REMOTE="origin"
            BRANCH="$current_branch"
        fi
    elif [ -z "$BRANCH" ] && [ -z "$HAS_ALL" ]; then
        BRANCH="$current_branch"
    fi
    
    echo "📥 Pulling from remote repository..."
    __jwgit_kv__ "Remote:" "$REMOTE"
    if [ -n "$BRANCH" ] && [ -z "$HAS_ALL" ]; then
        __jwgit_kv__ "Branch:" "$BRANCH"
    fi
    if [ ${#OPTS[@]} -gt 0 ]; then
        __jwgit_kv__ "Options:" "${OPTS[*]}"
    fi
    if [ -n "$REBASE" ]; then
        __jwgit_kv__ "Mode:" "Rebase (instead of merge)"
    fi
    echo
    
    # Validate remote
    if ! git remote | grep -qxF "$REMOTE"; then
        echo "❌ Remote '$REMOTE' not found"
        echo
        echo "Available remotes:"
        git remote | sed 's/^/  /'
        return 1
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        echo "⚠️  You have uncommitted changes!"
        git status --porcelain | head -5 | sed 's/^/  /'
        echo
        
        if [ -n "$REBASE" ]; then
            echo "💡 Rebase requires a clean working directory"
            echo "Commit or stash your changes first"
            return 1
        else
            echo -n "Continue with pull? [y/N] "
            read -r response
            if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
                echo "Pull cancelled"
                echo "💡 Commit or stash your changes first"
                return 1
            fi
        fi
    fi
    
    # Show what will be pulled (fetch first to check)
    echo "Fetching latest changes..."
    git fetch "$REMOTE" >/dev/null 2>&1
    
    if [ -n "$BRANCH" ] && [ -z "$HAS_ALL" ]; then
        echo
        __jwgit_h__ "Changes to Pull"
        
        if git show-ref --verify --quiet "refs/remotes/$REMOTE/$BRANCH"; then
            local commits_to_pull
            commits_to_pull=$(git rev-list --count HEAD.."$REMOTE/$BRANCH" 2>/dev/null || echo "0")
            
            if [ "$commits_to_pull" -gt 0 ]; then
                echo "New commits to pull: $commits_to_pull"
                git log --oneline HEAD.."$REMOTE/$BRANCH" | head -5 | sed 's/^/  /'
                if [ "$commits_to_pull" -gt 5 ]; then
                    echo "  ... and $((commits_to_pull - 5)) more commits"
                fi
                
                # Check for potential conflicts
                local local_commits
                local_commits=$(git rev-list --count "$REMOTE/$BRANCH"..HEAD 2>/dev/null || echo "0")
                if [ "$local_commits" -gt 0 ]; then
                    echo
                    echo "⚠️  You have $local_commits local commits that will be merged/rebased"
                    git log --oneline "$REMOTE/$BRANCH"..HEAD | head -3 | sed 's/^/  /'
                fi
            else
                echo "Branch is up to date"
                return 0
            fi
        else
            echo "❌ Remote branch '$REMOTE/$BRANCH' not found"
            echo
            echo "Available remote branches:"
            git branch -r | grep "^  $REMOTE/" | sed 's/^/  /' | head -10
            return 1
        fi
        echo
    fi
    
    # Build the pull argv as an array (no eval — safe under bash and zsh)
    local -a CMD=(pull)
    [ -n "$REBASE" ] && CMD+=(--rebase)
    CMD+=("${OPTS[@]}")
    CMD+=("$REMOTE")
    if [ -n "$BRANCH" ] && [ -z "$HAS_ALL" ]; then
        CMD+=("$BRANCH")
    fi

    # Execute pull
    echo "Pulling changes..."
    git "${CMD[@]}"
    local pull_result=$?
    
    if [ $pull_result -eq 0 ]; then
        echo
        echo "✅ Pull completed successfully!"
        echo
        __jwgit_h__ "Pull Summary"
        __jwgit_kv__ "Remote:" "$REMOTE"
        if [ -n "$BRANCH" ]; then
            __jwgit_kv__ "Branch:" "$BRANCH"
        fi
        __jwgit_kv__ "Latest commit:" "$(git log -1 --oneline)"

        # Show final status
        if [ -n "$current_branch" ]; then
            local upstream=""
            upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
            if [ -n "$upstream" ]; then
                __jwgit_kv__ "Status:" "up to date with $upstream"
            fi
        fi
        
    else
        echo
        echo "❌ Pull failed!"
        echo
        if [ -n "$REBASE" ]; then
            echo "Rebase conflicts detected. To resolve:"
            echo "  1. Edit conflicted files"
            echo "  2. Run 'git add <file>' for each resolved file"
            echo "  3. Run 'jwgit_rebase --continue'"
            echo "  4. Or run 'jwgit_rebase --abort' to cancel"
        else
            echo "Merge conflicts detected. To resolve:"
            echo "  1. Edit conflicted files"
            echo "  2. Run 'git add <file>' for each resolved file"
            echo "  3. Run 'git commit' to complete the merge"
            echo "  4. Or run 'git merge --abort' to cancel"
        fi
        
        echo
        echo "Conflicted files:"
        git diff --name-only --diff-filter=U | sed 's/^/  /' 2>/dev/null || echo "  (checking conflicts...)"
        
        return 1
    fi
    echo
}


jwgit_fetch() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_fetch [remote] [options]"
        echo "Examples:"
        echo "  jwgit_fetch                    # Fetch from all remotes"
        echo "  jwgit_fetch origin             # Fetch from origin"
        echo "  jwgit_fetch --all              # Fetch from all remotes"
        echo "  jwgit_fetch --prune            # Fetch and prune deleted branches"
        echo "  jwgit_fetch --tags             # Fetch all tags"
        echo "  jwgit_fetch origin --dry-run   # Show what would be fetched"
        echo
        echo "Available remotes:"
        if git remote | grep -q .; then
            git remote -v | sed 's/^/  /'
        else
            echo "  (no remotes configured)"
        fi
        echo
        echo "Current branch status:"
        local current_branch
        current_branch=$(git branch --show-current 2>/dev/null)
        if [ -n "$current_branch" ]; then
            local upstream=""
            upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
            if [ -n "$upstream" ]; then
                echo "  Branch: $current_branch -> $upstream"
            else
                echo "  Branch: $current_branch (no upstream)"
            fi
        else
            echo "  (not on any branch)"
        fi
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local REMOTE=""
    local -a OPTS=()
    local FETCH_ALL=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            --all|-a)
                FETCH_ALL="--all"
                shift
                ;;
            -*)
                OPTS+=("$1")
                shift
                ;;
            *)
                if [ -z "$REMOTE" ]; then
                    REMOTE="$1"
                else
                    OPTS+=("$1")
                fi
                shift
                ;;
        esac
    done

    # Set default remote if not specified and not fetching all
    if [ -z "$REMOTE" ] && [ -z "$FETCH_ALL" ]; then
        if git remote | grep -qxF origin; then
            REMOTE="origin"
        else
            FETCH_ALL="--all"
        fi
    fi
    
    echo "📡 Fetching from remote repository..."
    if [ -n "$FETCH_ALL" ]; then
        __jwgit_kv__ "Mode:" "Fetch from all remotes"
    else
        __jwgit_kv__ "Remote:" "$REMOTE"
    fi
    if [ ${#OPTS[@]} -gt 0 ]; then
        __jwgit_kv__ "Options:" "${OPTS[*]}"
    fi
    echo
    
    # Validate remote (if specified)
    if [ -n "$REMOTE" ] && ! git remote | grep -qxF "$REMOTE"; then
        echo "❌ Remote '$REMOTE' not found"
        echo
        echo "Available remotes:"
        git remote | sed 's/^/  /'
        return 1
    fi
    
    # Show current remote branch status before fetch
    __jwgit_h__ "Before Fetch"
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    
    if [ -n "$current_branch" ]; then
        local upstream=""
        upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
        if [ -n "$upstream" ]; then
            __jwgit_kv__ "Current branch:" "$current_branch"
            __jwgit_kv__ "Upstream:" "$upstream"

            # Show ahead/behind status
            local ahead_behind
            ahead_behind=$(git rev-list --left-right --count "$current_branch...$upstream" 2>/dev/null)
            if [ -n "$ahead_behind" ]; then
                local ahead
                local behind
                ahead=$(echo "$ahead_behind" | cut -f1)
                behind=$(echo "$ahead_behind" | cut -f2)
                __jwgit_kv__ "Status:" "$ahead ahead, $behind behind"
            fi
        else
            __jwgit_kv__ "Current branch:" "$current_branch (no upstream)"
        fi
    fi
    echo
    
    # Build the fetch argv as an array (no eval — safe under bash and zsh)
    local -a CMD=(fetch)
    if [ -n "$FETCH_ALL" ]; then
        CMD+=(--all)
    else
        CMD+=("$REMOTE")
    fi
    CMD+=("${OPTS[@]}")

    # Execute fetch
    echo "Fetching..."
    git "${CMD[@]}"
    local fetch_result=$?
    
    if [ $fetch_result -eq 0 ]; then
        echo
        echo "✅ Fetch completed successfully!"
        echo
        __jwgit_h__ "After Fetch"
        
        # Show updated status for current branch
        if [ -n "$current_branch" ]; then
            local upstream=""
            upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
            if [ -n "$upstream" ]; then
                __jwgit_kv__ "Current branch:" "$current_branch"
                __jwgit_kv__ "Upstream:" "$upstream"

                # Show updated ahead/behind status
                local ahead_behind=""
                ahead_behind=$(git rev-list --left-right --count "$current_branch...$upstream" 2>/dev/null)
                if [ -n "$ahead_behind" ]; then
                    local ahead="" behind=""
                    ahead=$(echo "$ahead_behind" | cut -f1)
                    behind=$(echo "$ahead_behind" | cut -f2)
                    __jwgit_kv__ "Status:" "$ahead ahead, $behind behind"
                    
                    if [ "$behind" -gt 0 ]; then
                        echo
                        echo "New commits available:"
                        git log --oneline "$current_branch..$upstream" | head -5 | sed 's/^/  /'
                        if [ "$behind" -gt 5 ]; then
                            echo "  ... and $((behind - 5)) more commits"
                        fi
                        echo
                        echo "💡 Run 'jwgit_pull' to merge these changes"
                    elif [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
                        echo "✅ Branch is up to date"
                    fi
                fi
            fi
        fi
        
        # Show summary of fetched branches
        echo
        __jwgit_h__ "Remote Branches"
        if [ -n "$REMOTE" ]; then
            git branch -r | grep "^  $REMOTE/" | head -10 | sed 's/^/  /'
            local remote_branch_count
            remote_branch_count=$(git branch -r | grep -c "^  $REMOTE/")
            if [ "$remote_branch_count" -gt 10 ]; then
                echo "  ... and $((remote_branch_count - 10)) more branches"
            fi
        else
            git branch -r | head -10 | sed 's/^/  /'
            local total_remote_branches
            total_remote_branches=$(git branch -r | wc -l)
            if [ "$total_remote_branches" -gt 10 ]; then
                echo "  ... and $((total_remote_branches - 10)) more branches"
            fi
        fi
        
    else
        echo
        echo "❌ Fetch failed!"
        echo
        echo "Common issues:"
        echo "  - Network connectivity problems"
        echo "  - Authentication issues"
        echo "  - Remote repository not accessible"
        echo "  - Invalid remote URL"
        
        return 1
    fi
    echo
}


# ---------------------------------------------------------------------------------
# history & information
# ---------------------------------------------------------------------------------

jwgit_log() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_log [options] [branch|commit] [-- file]"
        echo "Examples:"
        echo "  jwgit_log                      # Show commit history (most recent first)"
        echo "  jwgit_log --oneline            # Compact one-line format"
        echo "  jwgit_log --graph              # Show branch graph"
        echo "  jwgit_log -10                  # Show last 10 commits"
        echo "  jwgit_log main                 # Show commits from main branch"
        echo "  jwgit_log --since=\"2 weeks\"   # Show commits from last 2 weeks"
        echo "  jwgit_log --author=\"John\"     # Show commits by author"
        echo "  jwgit_log -- file.txt          # Show commits affecting file"
        echo
        echo "Quick options:"
        echo "  --oneline     Compact format"
        echo "  --graph       Show branch graph"
        echo "  --stat        Show file statistics"
        echo "  --patch       Show full diff"
        echo "  --all         Show all branches"
        echo
        return 0
    fi

    local -a OPTS=()
    local BRANCH=""
    local -a FILES=()
    local SHOW_GRAPH=""
    local SHOW_STAT=""
    local ONELINE=""
    local LIMIT=""
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            --oneline)
                ONELINE="--oneline"
                shift
                ;;
            --graph)
                SHOW_GRAPH="--graph"
                shift
                ;;
            --stat)
                SHOW_STAT="--stat"
                shift
                ;;
            --patch|-p)
                OPTS+=(--patch)
                shift
                ;;
            --all)
                OPTS+=(--all)
                shift
                ;;
            --since=*|--until=*|--author=*|--grep=*)
                OPTS+=("$1")
                shift
                ;;
            --since|--until|--author|--grep)
                OPTS+=("$1" "$2")
                shift 2
                ;;
            -[0-9]*)
                LIMIT="$1"
                shift
                ;;
            --)
                shift
                FILES=("$@")
                break
                ;;
            -*)
                OPTS+=("$1")
                shift
                ;;
            *)
                if [ -z "$BRANCH" ]; then
                    BRANCH="$1"
                else
                    OPTS+=("$1")
                fi
                shift
                ;;
        esac
    done
    
    # No artificial commit cap: with no -N given, show the full history and let
    # git's pager handle volume (like native `git log`). Pass -N to limit.

    echo "📜 Git Commit History"
    echo "=================================================="
    echo
    
    # Show repository info
    __jwgit_h__ "Repository Info"
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$current_branch" ]; then
        echo "Current branch: $current_branch"
    fi
    
    if [ -n "$BRANCH" ] && [ "$BRANCH" != "$current_branch" ]; then
        echo "Showing: $BRANCH"
    fi
    
    if [ ${#FILES[@]} -gt 0 ]; then
        echo "File filter: ${FILES[*]}"
    fi

    local total_commits
    if [ -n "$BRANCH" ]; then
        total_commits=$(git rev-list --count "$BRANCH" 2>/dev/null || echo "0")
    else
        total_commits=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    fi
    echo "Total commits: $total_commits"
    echo
    
    # Build the git log argv as an array (no eval — safe under bash and zsh)
    local -a CMD=(log)
    if [ -n "$ONELINE" ]; then
        CMD+=(--oneline)
    else
        CMD+=("--format=%C(yellow)%h%C(reset) - %C(green)(%cr)%C(reset) %s %C(blue)<%an>%C(reset)")
    fi
    [ -n "$SHOW_GRAPH" ] && CMD+=(--graph)
    [ -n "$SHOW_STAT" ] && CMD+=(--stat)
    [ -n "$LIMIT" ] && CMD+=("$LIMIT")
    CMD+=("${OPTS[@]}")
    [ -n "$BRANCH" ] && CMD+=("$BRANCH")
    [ ${#FILES[@]} -gt 0 ] && CMD+=(-- "${FILES[@]}")

    # Execute the log command
    __jwgit_h__ "Commit History"
    git "${CMD[@]}" 2>/dev/null || {
        echo "❌ Failed to show log"
        if [ -n "$BRANCH" ]; then
            echo "Branch '$BRANCH' may not exist"
            echo
            echo "Available branches:"
            git branch --format="  %(refname:short)" | head -10
        fi
        return 1
    }
    
    echo
    echo "💡 Use 'jwgit_log --help' for more options"
    echo
}


# row helper: left-pad a label to a fixed column so values line up in a column.
# Optional 3rd arg overrides the column width (default 18) for blocks whose
# longest label differs from the status block's (e.g. prune=10, blame=8).
__jwgit_kv__() {
    printf "%-${3:-18}s%s\n" "$1" "$2"
}

# A section header "---[ Title ]---", rendered bold + yellow via jw_colors.sh's
# jwpaintfg* helpers when that file is sourced; plain otherwise — so
# jw_functions__git.sh works sourced standalone (no raw ANSI here, no hard
# dependency on jw_colors.sh).
__jwgit_h__() {
    if command -v jwpaintfgBold >/dev/null 2>&1 && command -v jwpaintfgYellow >/dev/null 2>&1; then
        jwpaintfgBold "$(jwpaintfgYellow "---[ $1 ]---")"
    else
        echo "---[ $1 ]---"
    fi
}

jwgit_status() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_status"
        echo "Repository status: branch, upstream, ahead/behind, staged & unstaged files."
        return 0
    fi
    __jwgit_status__
}

# internal: the rich status report (no flag parsing); also called after staging.
__jwgit_status__() {
    echo "📊 Git Repository Status"
    echo "=================================================="
    echo
    
    # Repository info
    __jwgit_h__ "Repository Info"
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$repo_root" ]; then
        __jwgit_kv__ "Repository:" "$(basename "$repo_root")"
        __jwgit_kv__ "Location:" "$repo_root"
    else
        echo "❌ Not in a git repository"
        return 1
    fi
    
    # Branch information
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$current_branch" ]; then
        __jwgit_kv__ "Current branch:" "$current_branch"

        # Upstream information
        local upstream=""
        upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
        if [ -n "$upstream" ]; then
            __jwgit_kv__ "Upstream:" "$upstream"

            # Ahead/behind status
            local ahead_behind
            ahead_behind=$(git rev-list --left-right --count "$current_branch...$upstream" 2>/dev/null)
            if [ -n "$ahead_behind" ]; then
                local ahead
                local behind
                ahead=$(echo "$ahead_behind" | cut -f1)
                behind=$(echo "$ahead_behind" | cut -f2)

                if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
                    __jwgit_kv__ "Status:" "$ahead ahead, $behind behind"
                else
                    __jwgit_kv__ "Status:" "up to date"
                fi
            fi
        else
            __jwgit_kv__ "Upstream:" "(not set)"
        fi
    else
        local current_commit
        current_commit=$(git rev-parse --short HEAD 2>/dev/null)
        if [ -n "$current_commit" ]; then
            __jwgit_kv__ "HEAD:" "$current_commit (detached)"
        else
            __jwgit_kv__ "HEAD:" "(no commits yet)"
        fi
    fi
    
    # Latest commit
    local latest_commit
    latest_commit=$(git log -1 --oneline 2>/dev/null)
    if [ -n "$latest_commit" ]; then
        __jwgit_kv__ "Latest commit:" "$latest_commit"
    fi
    echo
    
    # Working directory status
    __jwgit_h__ "Working Directory"
    
    # Get status counts
    local staged_count
    local modified_count
    local untracked_count
    local deleted_count
    local line st file

    staged_count=$(git status --porcelain | grep -c "^[MADRC]")
    modified_count=$(git status --porcelain | grep -c "^ [MD]")
    untracked_count=$(git status --porcelain | grep -c "^??")
    deleted_count=$(git status --porcelain | grep -c "^ D\|^D ")
    
    __jwgit_kv__ "Staged files:" "$staged_count"
    __jwgit_kv__ "Modified files:" "$modified_count"
    __jwgit_kv__ "Untracked files:" "$untracked_count"
    __jwgit_kv__ "Deleted files:" "$deleted_count"
    
    # Show detailed status if there are changes
    if [ "$staged_count" -gt 0 ] || [ "$modified_count" -gt 0 ] || [ "$untracked_count" -gt 0 ]; then
        echo
        
        # Staged files
        if [ "$staged_count" -gt 0 ]; then
            __jwgit_h__ "Staged Files"
            git status --porcelain | grep "^[MADRC]" | head -10 | while IFS= read -r line; do
                st=$(echo "$line" | cut -c1-2)
                file=$(echo "$line" | cut -c4-)
                case $st in
                    A*) echo "  ✅ $file (new file)" ;;
                    M*) echo "  📝 $file (modified)" ;;
                    D*) echo "  🗑️  $file (deleted)" ;;
                    R*) echo "  🔄 $file (renamed)" ;;
                    C*) echo "  📋 $file (copied)" ;;
                    *) echo "  $st $file" ;;
                esac
            done
            
            if [ "$staged_count" -gt 10 ]; then
                echo "  ... and $((staged_count - 10)) more files"
            fi
            echo
        fi
        
        # Modified files
        if [ "$modified_count" -gt 0 ]; then
            __jwgit_h__ "Modified Files"
            git status --porcelain | grep "^ [MD]" | head -10 | while IFS= read -r line; do
                st=$(echo "$line" | cut -c1-2)
                file=$(echo "$line" | cut -c4-)
                case $st in
                    " M") echo "  📝 $file (modified)" ;;
                    " D") echo "  🗑️  $file (deleted)" ;;
                    *) echo "  $st $file" ;;
                esac
            done
            
            if [ "$modified_count" -gt 10 ]; then
                echo "  ... and $((modified_count - 10)) more files"
            fi
            echo
        fi
        
        # Untracked files
        if [ "$untracked_count" -gt 0 ]; then
            __jwgit_h__ "Untracked Files"
            git status --porcelain | grep "^??" | head -10 | while IFS= read -r line; do
                file=$(echo "$line" | cut -c4-)
                echo "  ❓ $file"
            done
            
            if [ "$untracked_count" -gt 10 ]; then
                echo "  ... and $((untracked_count - 10)) more files"
            fi
            echo
        fi
        
    else
        echo "✅ Working directory is clean"
        echo
    fi
    
    # Stash information
    local stash_count
    stash_count=$(git stash list | wc -l 2>/dev/null || echo "0")
    if [ "$stash_count" -gt 0 ]; then
        __jwgit_h__ "Stashes"
        __jwgit_kv__ "Stashed changes:" "$stash_count"
        git stash list | head -3 | sed 's/^/  /'
        if [ "$stash_count" -gt 3 ]; then
            echo "  ... and $((stash_count - 3)) more stashes"
        fi
        echo
    fi
    
    # Recent activity
    __jwgit_h__ "Recent Activity"
    echo "Recent commits (last 5):"
    git log --oneline -5 | sed 's/^/  /' 2>/dev/null || echo "  (no commits)"
    echo
    
    # Remotes
    __jwgit_h__ "Remotes"
    if git remote | grep -q .; then
        git remote -v | sed 's/^/  /'
    else
        echo "  (no remotes configured)"
    fi
    echo
    
    # Quick actions
    __jwgit_h__ "Quick Actions"
    if [ "$staged_count" -gt 0 ]; then
        echo "💡 Ready to commit: jwgit_commit"
    elif [ "$modified_count" -gt 0 ] || [ "$untracked_count" -gt 0 ]; then
        echo "💡 Stage changes: jwgit_add ."
    fi
    
    if [ -n "$upstream" ]; then
        behind=$(git rev-list --count HEAD.."$upstream" 2>/dev/null || echo "0")
        if [ "$behind" -gt 0 ]; then
            echo "💡 Pull updates: jwgit_pull"
        fi

        ahead=$(git rev-list --count "$upstream"..HEAD 2>/dev/null || echo "0")
        if [ "$ahead" -gt 0 ]; then
            echo "💡 Push changes: jwgit_push"
        fi
    fi
    echo
}


jwgit_diff() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_diff [options] [commit] [commit] [-- file]"
        echo "Examples:"
        echo "  jwgit_diff                     # Show unstaged changes"
        echo "  jwgit_diff --cached            # Show staged changes"
        echo "  jwgit_diff HEAD~1              # Compare with previous commit"
        echo "  jwgit_diff main feature        # Compare two branches"
        echo "  jwgit_diff --stat              # Show file statistics only"
        echo "  jwgit_diff --name-only         # Show only changed file names"
        echo "  jwgit_diff -- file.txt         # Show changes for specific file"
        echo
        echo "Quick options:"
        echo "  --cached      Show staged changes"
        echo "  --stat        Show file statistics"
        echo "  --name-only   Show only file names"
        echo "  --word-diff   Show word-level changes"
        echo
        echo "Current status:"
        if git status --porcelain | grep -q .; then
            echo "Modified files:"
            git status --porcelain | grep "^ M\|^M " | head -5 | sed 's/^/  /'
            echo "Staged files:"
            git status --porcelain | grep "^[MADRC]" | head -5 | sed 's/^/  /'
        else
            echo "  (no changes to show)"
        fi
        echo
        return 0
    fi

    local -a OPTS=()
    local COMMIT1=""
    local COMMIT2=""
    local -a FILES=()
    local CACHED=""
    local STAT_ONLY=""
    local NAME_ONLY=""
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            --cached|--staged)
                CACHED="--cached"
                shift
                ;;
            --stat)
                STAT_ONLY="--stat"
                shift
                ;;
            --name-only)
                NAME_ONLY="--name-only"
                shift
                ;;
            --word-diff|--color-words)
                OPTS+=("$1")
                shift
                ;;
            --)
                shift
                FILES=("$@")
                break
                ;;
            -*)
                OPTS+=("$1")
                shift
                ;;
            *)
                if [ -z "$COMMIT1" ]; then
                    COMMIT1="$1"
                elif [ -z "$COMMIT2" ]; then
                    COMMIT2="$1"
                else
                    OPTS+=("$1")
                fi
                shift
                ;;
        esac
    done
    
    echo "📊 Git Diff"
    echo "=================================================="
    echo
    
    # Determine what we're comparing
    local diff_description=""
    if [ -n "$CACHED" ]; then
        diff_description="Staged changes (ready to commit)"
    elif [ -n "$COMMIT1" ] && [ -n "$COMMIT2" ]; then
        diff_description="Comparing $COMMIT1 with $COMMIT2"
    elif [ -n "$COMMIT1" ]; then
        diff_description="Changes from $COMMIT1 to working directory"
    else
        diff_description="Unstaged changes in working directory"
    fi
    
    __jwgit_h__ "Diff Info"
    __jwgit_kv__ "Comparing:" "$diff_description"
    if [ ${#FILES[@]} -gt 0 ]; then
        __jwgit_kv__ "File filter:" "${FILES[*]}"
    fi
    echo
    
    # Build the diff argv as arrays (no eval — safe under bash and zsh)
    local -a DIFF=(diff)
    [ -n "$CACHED" ] && DIFF+=(--cached)
    if [ -n "$STAT_ONLY" ]; then
        DIFF+=(--stat)
    elif [ -n "$NAME_ONLY" ]; then
        DIFF+=(--name-only)
    fi
    DIFF+=("${OPTS[@]}")
    [ -n "$COMMIT1" ] && DIFF+=("$COMMIT1")
    [ -n "$COMMIT2" ] && DIFF+=("$COMMIT2")
    [ ${#FILES[@]} -gt 0 ] && DIFF+=(-- "${FILES[@]}")

    # Show summary first
    __jwgit_h__ "Summary"
    local -a SUM=(diff)
    [ -n "$CACHED" ] && SUM+=(--cached)
    [ -n "$COMMIT1" ] && SUM+=("$COMMIT1")
    [ -n "$COMMIT2" ] && SUM+=("$COMMIT2")
    [ ${#FILES[@]} -gt 0 ] && SUM+=(-- "${FILES[@]}")
    
    # Get file count and line changes
    local files_changed
    local insertions
    local deletions
    
    local stat_output
    stat_output=$(git "${SUM[@]}" --stat 2>/dev/null)
    
    if [ -n "$stat_output" ]; then
        files_changed=$(echo "$stat_output" | tail -1 | grep -o '[0-9]* file' | cut -d' ' -f1 || echo "0")
        insertions=$(echo "$stat_output" | tail -1 | grep -o '[0-9]* insertion' | cut -d' ' -f1 || echo "0")
        deletions=$(echo "$stat_output" | tail -1 | grep -o '[0-9]* deletion' | cut -d' ' -f1 || echo "0")
        
        __jwgit_kv__ "Files changed:" "$files_changed"
        __jwgit_kv__ "Insertions:" "+$insertions"
        __jwgit_kv__ "Deletions:" "-$deletions"
        echo
        
        # Show file list with changes
        __jwgit_h__ "Changed Files"
        git "${SUM[@]}" --name-status | while read -r st file; do
            case $st in
                A) echo "  ✅ $file (added)" ;;
                M) echo "  📝 $file (modified)" ;;
                D) echo "  🗑️  $file (deleted)" ;;
                R*) echo "  🔄 $file (renamed)" ;;
                C*) echo "  📋 $file (copied)" ;;
                *) echo "  $st $file" ;;
            esac
        done
        echo
    else
        echo "No changes to show"
        return 0
    fi
    
    # Show the actual diff
    if [ -z "$STAT_ONLY" ] && [ -z "$NAME_ONLY" ]; then
        __jwgit_h__ "Diff Content"
        git "${DIFF[@]}" 2>/dev/null || {
            echo "❌ Failed to show diff"
            if [ -n "$COMMIT1" ]; then
                echo "Commit '$COMMIT1' may not exist"
            fi
            if [ -n "$COMMIT2" ]; then
                echo "Commit '$COMMIT2' may not exist"
            fi
            return 1
        }
    else
        # For stat or name-only, show the output
        __jwgit_h__ "Diff Output"
        git "${DIFF[@]}"
    fi
    
    echo
    echo "💡 Use 'jwgit_diff --help' for more options"
    echo
}


jwgit_blame() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_blame <file> [options]"
        echo "Examples:"
        echo "  jwgit_blame file.txt           # Show line-by-line authorship"
        echo "  jwgit_blame file.txt -L 10,20  # Show lines 10-20 only"
        echo "  jwgit_blame file.txt --since=\"1 month ago\""
        echo "  jwgit_blame file.txt -w        # Ignore whitespace changes"
        echo
        echo "Available files to blame:"
        if git ls-files >/dev/null 2>&1; then
            git ls-files | head -20 | sed 's/^/  /'
            local total_files
            total_files=$(git ls-files | wc -l)
            if [ "$total_files" -gt 20 ]; then
                echo "  ... and $((total_files - 20)) more files"
            fi
        else
            echo "  (not in a git repository)"
        fi
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local FILE=$1
    shift
    local -a OPTS=("$@")
    
    # Check if file exists
    if [ ! -f "$FILE" ]; then
        echo "❌ File '$FILE' not found"
        echo
        echo "Available files:"
        git ls-files | grep -i "$(basename "$FILE")" | head -10 | sed 's/^/  /' || echo "  (no matching files)"
        return 1
    fi
    
    # Check if file is tracked by git
    if ! git ls-files --error-unmatch "$FILE" >/dev/null 2>&1; then
        echo "❌ File '$FILE' is not tracked by git"
        echo "💡 Add it first with: jwgit_add $FILE"
        return 1
    fi
    
    echo "🔍 Git Blame: $FILE"
    echo "=================================================="
    echo
    
    # Show file info
    __jwgit_h__ "File Info"
    __jwgit_kv__ "File:" "$FILE" 8
    __jwgit_kv__ "Size:" "$(wc -l < "$FILE") lines" 8
    
    # Show recent commits affecting this file
    echo "Recent commits affecting this file:"
    git log --oneline -5 -- "$FILE" | sed 's/^/  /' 2>/dev/null || echo "  (no commits found)"
    echo
    
    # Show blame with enhanced formatting
    __jwgit_h__ "Blame Output"
    echo "Format: [commit] (author date) line_number: content"
    echo
    
    # Build the blame argv as an array (no eval — safe under bash and zsh)
    local -a CMD=(blame --color-lines --color-by-age)
    CMD+=("${OPTS[@]}")
    CMD+=("$FILE")

    # Execute blame
    git "${CMD[@]}" 2>/dev/null || {
        echo "❌ Failed to show blame for '$FILE'"
        echo
        echo "Possible reasons:"
        echo "  - File has no commit history"
        echo "  - Invalid line range specified"
        echo "  - File was recently added but not committed"
        return 1
    }
    
    echo
    __jwgit_h__ "Blame Summary"
    
    # Show author statistics
    echo "Authors contributing to this file:"
    local count author_line author
    git blame --porcelain "$FILE" 2>/dev/null | grep "^author " | sort | uniq -c | sort -rn | head -10 | while read -r count author_line; do
        author=$(echo "$author_line" | cut -d' ' -f2-)
        echo "  $author: $count lines"
    done
    
    echo
    echo "💡 Use 'git show <commit>' to see full commit details"
    echo
}


# ---------------------------------------------------------------------------------
# maintenance & cleanup
# ---------------------------------------------------------------------------------

jwgit_clean() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_clean [options]"
        echo "Examples:"
        echo "  jwgit_clean                    # Show what would be cleaned (dry run)"
        echo "  jwgit_clean -f                 # Remove untracked files"
        echo "  jwgit_clean -fd                # Remove untracked files and directories"
        echo "  jwgit_clean -fx                # Remove untracked and ignored files"
        echo "  jwgit_clean -i                 # Interactive cleaning"
        echo
        echo "⚠️  WARNING: This will permanently delete files!"
        echo
        echo "Current untracked files:"
        if git status --porcelain | grep "^??" | grep -q .; then
            git status --porcelain | grep "^??" | head -10 | sed 's/^??/  /' | sed 's/^ */  /'
            local untracked_count
            untracked_count=$(git status --porcelain | grep -c "^??")
            if [ "$untracked_count" -gt 10 ]; then
                echo "  ... and $((untracked_count - 10)) more files"
            fi
        else
            echo "  (no untracked files)"
        fi
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local FORCE=""
    local DIRECTORIES=""
    local IGNORED=""
    local INTERACTIVE=""
    local DRY_RUN=""
    
    # Parse options
    while [ $# -gt 0 ]; do
        case $1 in
            -f|--force)
                FORCE="-f"
                shift
                ;;
            -d)
                DIRECTORIES="-d"
                shift
                ;;
            -x)
                IGNORED="-x"
                shift
                ;;
            -i|--interactive)
                INTERACTIVE="-i"
                shift
                ;;
            -n|--dry-run)
                DRY_RUN="-n"
                shift
                ;;
            -fd|-df)
                FORCE="-f"
                DIRECTORIES="-d"
                shift
                ;;
            -fx|-xf)
                FORCE="-f"
                IGNORED="-x"
                shift
                ;;
            -fdx|-dfx|-xfd|-xdf|-fxd|-dxf)
                FORCE="-f"
                DIRECTORIES="-d"
                IGNORED="-x"
                shift
                ;;
            *)
                echo "❌ Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    # Default to dry run if no force flag
    if [ -z "$FORCE" ] && [ -z "$INTERACTIVE" ]; then
        DRY_RUN="-n"
    fi
    
    echo "🧹 Git Clean"
    echo "=================================================="
    echo
    
    # Show what will be cleaned
    __jwgit_h__ "Clean Preview"
    
    # Preview is ALWAYS a dry run (-n) so the file list shows even in force
    # mode; building argv as an array avoids eval.
    local -a PREVIEW=(clean -n)
    [ -n "$DIRECTORIES" ] && PREVIEW+=(-d)
    [ -n "$IGNORED" ] && PREVIEW+=(-x)

    local files_to_clean
    files_to_clean=$(git "${PREVIEW[@]}" 2>/dev/null)
    
    if [ -z "$files_to_clean" ]; then
        echo "✅ No files to clean"
        return 0
    fi
    
    echo "Files that will be removed:"
    echo "$files_to_clean" | sed 's/^Would remove /  🗑️  /' | sed 's/^Removing /  🗑️  /'
    
    local file_count
    file_count=$(echo "$files_to_clean" | wc -l)
    echo
    echo "Total items: $file_count"
    
    # Explain what each option does
    echo
    __jwgit_h__ "Clean Options"
    if [ -n "$DIRECTORIES" ]; then
        echo "✅ Will remove untracked directories"
    else
        echo "⚠️  Will NOT remove directories (use -d to include)"
    fi
    
    if [ -n "$IGNORED" ]; then
        echo "✅ Will remove ignored files (.gitignore)"
    else
        echo "⚠️  Will NOT remove ignored files (use -x to include)"
    fi
    
    if [ -n "$INTERACTIVE" ]; then
        echo "✅ Interactive mode - you'll be prompted for each file"
    fi
    
    # If this is a dry run, show how to actually clean
    if [ -n "$DRY_RUN" ]; then
        echo
        __jwgit_h__ "To Actually Clean"
        echo "This was a dry run. To actually remove files:"
        
        local actual_cmd="jwgit_clean -f"
        if [ -n "$DIRECTORIES" ]; then
            actual_cmd="${actual_cmd}d"
        fi
        if [ -n "$IGNORED" ]; then
            actual_cmd="${actual_cmd}x"
        fi
        
        echo "  $actual_cmd"
        echo
        echo "Or use interactive mode:"
        echo "  jwgit_clean -i"
        return 0
    fi
    
    # Confirmation for destructive operation
    if [ -z "$INTERACTIVE" ]; then
        echo
        echo "⚠️  WARNING: This will permanently delete $file_count items!"
        echo -n "Continue? [y/N] "
        read -r response
        
        if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
            echo "Clean cancelled"
            return 1
        fi
    fi
    
    # Perform the clean
    echo
    __jwgit_h__ "Cleaning"
    
    local -a FINAL=(clean)
    [ -n "$FORCE" ] && FINAL+=(-f)
    [ -n "$DIRECTORIES" ] && FINAL+=(-d)
    [ -n "$IGNORED" ] && FINAL+=(-x)
    [ -n "$INTERACTIVE" ] && FINAL+=(-i)

    git "${FINAL[@]}"
    local clean_result=$?
    
    if [ $clean_result -eq 0 ]; then
        echo
        echo "✅ Clean completed successfully!"
        echo
        __jwgit_h__ "Final Status"
        local remaining_untracked
        remaining_untracked=$(git status --porcelain | grep -c "^??")
        echo "Remaining untracked files: $remaining_untracked"
        
        if [ "$remaining_untracked" -gt 0 ]; then
            echo "Remaining files:"
            git status --porcelain | grep "^??" | head -5 | sed 's/^??/  /' | sed 's/^ */  /'
        fi
        
    else
        echo "❌ Clean failed!"
        return 1
    fi
    echo
}


jwgit_prune() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_prune"
        echo "Deep maintenance: prune stale remote-tracking branches, expire unreachable"
        echo "reflog entries, then run aggressive gc. Prompts before doing anything."
        echo "⚠️  Removes unreachable objects irreversibly."
        return 0
    fi
    echo "🧹 Git Repository Maintenance"
    echo "=================================================="
    echo
    
    echo "This will perform repository cleanup and optimization:"
    echo "  - Remove unreachable objects"
    echo "  - Optimize repository structure"
    echo "  - Clean up reflog entries"
    echo "  - Prune remote tracking branches"
    echo
    echo -n "Continue with maintenance? [y/N] "
    read -r response
    
    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        echo "Maintenance cancelled"
        return 1
    fi
    
    echo
    __jwgit_h__ "Repository Size Before"
    local size_before
    size_before=$(du -sh .git 2>/dev/null | cut -f1 || echo "unknown")
    echo "Repository size: $size_before"
    echo
    
    __jwgit_h__ "Pruning Remote Branches"
    echo "Removing stale remote tracking branches..."
    git remote prune origin 2>/dev/null || echo "No origin remote or nothing to prune"
    
    # Prune all remotes
    git remote | while read -r remote; do
        if [ "$remote" != "origin" ]; then
            echo "Pruning remote: $remote"
            git remote prune "$remote" 2>/dev/null || echo "Nothing to prune for $remote"
        fi
    done
    echo
    
    __jwgit_h__ "Cleaning Reflog"
    echo "Expiring reflog entries for unreachable commits..."
    # Only drop reflog for unreachable commits (keeps your branches' normal
    # reflog window intact, unlike --expire=<date> --all which also trims it)
    git reflog expire --expire-unreachable=now --all
    echo
    
    __jwgit_h__ "Garbage Collection"
    echo "Running garbage collection..."
    git gc --prune=now --aggressive
    echo
    
    __jwgit_h__ "Repository Size After"
    local size_after
    size_after=$(du -sh .git 2>/dev/null | cut -f1 || echo "unknown")
    echo "Repository size: $size_after"
    echo
    
    __jwgit_h__ "Maintenance Summary"
    __jwgit_kv__ "Before:" "$size_before" 10
    __jwgit_kv__ "After:" "$size_after" 10

    # Show object count
    local object_count
    object_count=$(git count-objects -v | grep "count" | cut -d' ' -f2 || echo "unknown")
    __jwgit_kv__ "Objects:" "$object_count" 10

    # Show pack info
    local pack_count
    pack_count=$(git count-objects -v | grep "packs" | cut -d' ' -f2 || echo "0")
    __jwgit_kv__ "Packs:" "$pack_count" 10
    
    echo
    echo "✅ Repository maintenance completed!"
    echo
}


jwgit_gc() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_gc [--deep]"
        echo "  jwgit_gc           # Safe routine gc — keeps Git's prune grace period"
        echo "  jwgit_gc --deep    # Aggressive: --prune=now --aggressive (drops the safety net)"
        return 0
    fi

    local DEEP=""
    if [ "$1" = "--deep" ] || [ "$1" = "--aggressive" ]; then
        DEEP=1
    fi

    echo "🗑️  Git Garbage Collection"
    echo "=================================================="
    echo
    
    # Show repository info before cleanup
    __jwgit_h__ "Before Cleanup"
    echo "Repository statistics:"
    git count-objects -v | while read -r line; do
        echo "  $line"
    done
    echo
    
    local repo_size_before
    repo_size_before=$(du -sh .git 2>/dev/null | cut -f1 || echo "unknown")
    echo "Repository size: $repo_size_before"
    echo
    
    if [ -n "$DEEP" ]; then
        echo "⚠️  DEEP garbage collection will:"
        echo "  - Aggressively repack the object database"
        echo "  - Prune ALL unreachable objects immediately (no grace period)"
        echo "  - Remove the recovery safety net for recently-dangling commits"
    else
        echo "Garbage collection will (safe — keeps Git's recovery grace period):"
        echo "  - Compress and optimize the object database"
        echo "  - Remove only objects unreachable past Git's default window (~2 weeks)"
        echo "  💡 Use 'jwgit_gc --deep' to reclaim maximum space (destroys the safety net)"
    fi
    echo
    echo -n "Continue with garbage collection? [y/N] "
    read -r response
    
    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        echo "Garbage collection cancelled"
        return 1
    fi
    
    echo
    __jwgit_h__ "Running Garbage Collection"
    
    if [ -n "$DEEP" ]; then
        echo "Deep optimization (aggressive, pruning unreachable objects now)..."
        git gc --prune=now --aggressive
    else
        echo "Optimizing (safe — respecting Git's prune grace period)..."
        git gc
    fi
    
    echo
    __jwgit_h__ "After Cleanup"
    echo "Repository statistics:"
    git count-objects -v | while read -r line; do
        echo "  $line"
    done
    echo
    
    local repo_size_after
    repo_size_after=$(du -sh .git 2>/dev/null | cut -f1 || echo "unknown")
    echo "Repository size: $repo_size_after"
    echo
    
    __jwgit_h__ "Cleanup Summary"
    __jwgit_kv__ "Size before:" "$repo_size_before" 16
    __jwgit_kv__ "Size after:" "$repo_size_after" 16

    # Calculate objects cleaned up
    local objects_after
    objects_after=$(git count-objects | cut -d' ' -f1 || echo "0")
    __jwgit_kv__ "Loose objects:" "$objects_after" 16
    
    echo
    echo "✅ Garbage collection completed!"
    echo "💡 Repository is now optimized for better performance"
    echo
}


# ---------------------------------------------------------------------------------
# advanced operations
# ---------------------------------------------------------------------------------

jwgit_cherry-pick() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_cherry-pick <commit> [target_branch]"
        echo "Examples:"
        echo "  jwgit_cherry-pick abc123            # Cherry-pick commit to current branch"
        echo "  jwgit_cherry-pick abc123 main       # Cherry-pick commit to main branch"
        echo "  jwgit_cherry-pick --continue        # Continue after resolving conflicts"
        echo "  jwgit_cherry-pick --abort           # Abort cherry-pick"
        echo "  jwgit_cherry-pick --skip            # Skip current commit"
        echo
        echo "Recent commits available for cherry-picking:"
        if git log --oneline -10 >/dev/null 2>&1; then
            git log --oneline -10 | sed 's/^/  /'
        else
            echo "  (no commits available)"
        fi
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local COMMIT=$1
    local TARGET_BRANCH=$2
    
    # Handle cherry-pick control commands
    case $COMMIT in
        --continue)
            echo "Continuing cherry-pick after conflict resolution..."
            
            # Check if there are unresolved conflicts
            if git diff --name-only --diff-filter=U | grep -q .; then
                echo "❌ There are still unresolved conflicts:"
                git diff --name-only --diff-filter=U | sed 's/^/  /'
                echo
                echo "💡 Resolve conflicts and run 'git add <file>' for each resolved file"
                return 1
            fi
            
            if git cherry-pick --continue; then
                echo "✅ Cherry-pick completed successfully"
                echo "Latest commit: $(git log -1 --oneline)"
            else
                echo "❌ Failed to continue cherry-pick"
                return 1
            fi
            return 0
            ;;
            
        --abort)
            echo "Aborting current cherry-pick..."
            if git cherry-pick --abort; then
                echo "✅ Cherry-pick aborted successfully"
            else
                echo "❌ Failed to abort cherry-pick (no cherry-pick in progress?)"
                return 1
            fi
            return 0
            ;;
            
        --skip)
            echo "Skipping current commit during cherry-pick..."
            if git cherry-pick --skip; then
                echo "✅ Commit skipped, continuing cherry-pick"
            else
                echo "❌ Failed to skip commit"
                return 1
            fi
            return 0
            ;;
    esac
    
    # Validate commit
    if ! git rev-parse --verify "$COMMIT" >/dev/null 2>&1; then
        echo "❌ Invalid commit: $COMMIT"
        echo
        echo "Recent commits:"
        git log --oneline -10 | sed 's/^/  /'
        return 1
    fi
    
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    
    # Switch to target branch if specified
    if [ -n "$TARGET_BRANCH" ]; then
        if [ "$TARGET_BRANCH" != "$current_branch" ]; then
            echo "Switching to branch: $TARGET_BRANCH"
            if ! git checkout "$TARGET_BRANCH"; then
                echo "❌ Failed to switch to branch '$TARGET_BRANCH'"
                return 1
            fi
            current_branch="$TARGET_BRANCH"
        fi
    fi
    
    if [ -z "$current_branch" ]; then
        echo "❌ Cannot cherry-pick in detached HEAD state"
        echo "💡 Switch to a branch first"
        return 1
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        echo "⚠️  You have uncommitted changes!"
        git status --porcelain | head -5 | sed 's/^/  /'
        echo
        echo "💡 Commit or stash your changes before cherry-picking"
        return 1
    fi
    
    echo "🍒 Cherry-picking commit to '$current_branch'"
    echo "=================================================="
    echo
    
    # Show commit information
    __jwgit_h__ "Commit to Cherry-pick"
    git show --stat --oneline "$COMMIT" | head -10
    echo
    
    # Check if commit is already in current branch
    if git merge-base --is-ancestor "$COMMIT" HEAD 2>/dev/null; then
        echo "⚠️  This commit is already in the current branch history"
        echo -n "Continue anyway? [y/N] "
        read -r response
        if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
            echo "Cherry-pick cancelled"
            return 1
        fi
    fi
    
    __jwgit_h__ "Cherry-pick Operation"
    __jwgit_kv__ "Target branch:" "$current_branch"
    __jwgit_kv__ "Commit:" "$(git log -1 --oneline "$COMMIT")"
    echo
    echo -n "Proceed with cherry-pick? [y/N] "
    read -r response
    
    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        echo "Cherry-pick cancelled"
        return 1
    fi
    
    # Perform cherry-pick
    echo "Cherry-picking..."
    git cherry-pick "$COMMIT"
    
    local cherry_result=$?
    
    if [ $cherry_result -eq 0 ]; then
        echo
        echo "✅ Cherry-pick completed successfully!"
        echo
        __jwgit_h__ "Cherry-pick Summary"
        __jwgit_kv__ "Branch:" "$current_branch"
        __jwgit_kv__ "Cherry-picked:" "$(git log -1 --oneline "$COMMIT")"
        __jwgit_kv__ "New commit:" "$(git log -1 --oneline)"
        
    else
        echo
        echo "❌ Cherry-pick failed due to conflicts!"
        echo
        __jwgit_h__ "Conflicted Files"
        git diff --name-only --diff-filter=U | sed 's/^/  /'
        echo
        echo "💡 To resolve conflicts:"
        echo "   1. Edit the conflicted files"
        echo "   2. Run 'git add <file>' for each resolved file"
        echo "   3. Run 'jwgit_cherry-pick --continue' to complete the cherry-pick"
        echo "   4. Or run 'jwgit_cherry-pick --abort' to cancel the cherry-pick"
        echo "   5. Or run 'jwgit_cherry-pick --skip' to skip this commit"
        
        return 1
    fi
    echo
}


jwgit_bisect() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_bisect <start|good|bad|reset|skip|run> [commit]"
        echo "Examples:"
        echo "  jwgit_bisect start             # Start bisect session"
        echo "  jwgit_bisect bad               # Mark current commit as bad"
        echo "  jwgit_bisect good abc123       # Mark commit as good"
        echo "  jwgit_bisect skip              # Skip current commit"
        echo "  jwgit_bisect reset             # End bisect session"
        echo "  jwgit_bisect run \"make test\"   # Automate bisect with command"
        echo
        echo "Git bisect helps you find the commit that introduced a bug by"
        echo "using binary search through your commit history."
        echo
        echo "Typical workflow:"
        echo "  1. jwgit_bisect start"
        echo "  2. jwgit_bisect bad            # Current commit has the bug"
        echo "  3. jwgit_bisect good <commit>  # Known good commit"
        echo "  4. Test each commit git shows you"
        echo "  5. jwgit_bisect good/bad for each test"
        echo "  6. jwgit_bisect reset when done"
        echo
        [ $# -eq 0 ] && return 1 || return 0
    fi

    local ACTION=$1
    shift
    local ARGS="$*"
    
    case $ACTION in
        start)
            echo "🔍 Starting Git Bisect Session"
            echo "=================================================="
            echo
            
            # Check if already in bisect
            if [ -f ".git/BISECT_LOG" ]; then
                echo "⚠️  Bisect session already in progress"
                echo "Use 'jwgit_bisect reset' to end current session first"
                return 1
            fi
            
            echo "Starting bisect session..."
            if git bisect start; then
                echo "✅ Bisect session started!"
                echo
                echo "Next steps:"
                echo "  1. Mark the current (bad) commit: jwgit_bisect bad"
                echo "  2. Mark a known good commit: jwgit_bisect good <commit>"
                echo
                echo "Recent commits:"
                git log --oneline -10 | sed 's/^/  /'
            else
                echo "❌ Failed to start bisect session"
                return 1
            fi
            ;;
            
        bad)
            if [ ! -f ".git/BISECT_LOG" ]; then
                echo "❌ No bisect session in progress"
                echo "Start one with: jwgit_bisect start"
                return 1
            fi
            
            local COMMIT=${ARGS:-HEAD}
            echo "Marking commit as BAD: $COMMIT"
            
            git bisect bad "$COMMIT"
            local result=$?
            
            if [ $result -eq 0 ]; then
                echo "✅ Commit marked as bad"
                __jwgit_bisect_status__
            else
                echo "❌ Failed to mark commit as bad"
                return 1
            fi
            ;;
            
        good)
            if [ ! -f ".git/BISECT_LOG" ]; then
                echo "❌ No bisect session in progress"
                echo "Start one with: jwgit_bisect start"
                return 1
            fi
            
            local COMMIT=${ARGS:-HEAD}
            echo "Marking commit as GOOD: $COMMIT"
            
            git bisect good "$COMMIT"
            local result=$?
            
            if [ $result -eq 0 ]; then
                echo "✅ Commit marked as good"
                __jwgit_bisect_status__
            else
                echo "❌ Failed to mark commit as good"
                return 1
            fi
            ;;
            
        skip)
            if [ ! -f ".git/BISECT_LOG" ]; then
                echo "❌ No bisect session in progress"
                echo "Start one with: jwgit_bisect start"
                return 1
            fi
            
            echo "Skipping current commit..."
            if git bisect skip; then
                echo "✅ Commit skipped"
                __jwgit_bisect_status__
            else
                echo "❌ Failed to skip commit"
                return 1
            fi
            ;;
            
        reset)
            if [ ! -f ".git/BISECT_LOG" ]; then
                echo "No bisect session in progress"
                return 0
            fi
            
            echo "Ending bisect session..."
            if git bisect reset; then
                echo "✅ Bisect session ended"
                echo "Returned to original branch"
            else
                echo "❌ Failed to reset bisect session"
                return 1
            fi
            ;;
            
        run)
            if [ ! -f ".git/BISECT_LOG" ]; then
                echo "❌ No bisect session in progress"
                echo "Start one with: jwgit_bisect start"
                return 1
            fi
            
            if [ -z "$ARGS" ]; then
                echo "Usage: jwgit_bisect run \"<command>\""
                echo "Example: jwgit_bisect run \"make test\""
                return 1
            fi
            
            echo "Running automated bisect with command: $ARGS"
            echo "Command should exit with:"
            echo "  - 0 for good commits"
            echo "  - 1-124, 126-127 for bad commits"
            echo "  - 125 for untestable commits (skip)"
            echo
            echo -n "Continue? [y/N] "
            read -r response
            
            if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                if git bisect run sh -c "$ARGS"; then
                    echo "✅ Automated bisect completed!"
                    __jwgit_bisect_status__
                else
                    echo "❌ Automated bisect failed"
                    return 1
                fi
            else
                echo "Automated bisect cancelled"
            fi
            ;;
            
        status)
            __jwgit_bisect_status__
            ;;
            
        *)
            echo "❌ Unknown bisect action: $ACTION"
            echo "Valid actions: start, good, bad, skip, reset, run, status"
            return 1
            ;;
    esac
    echo
}

__jwgit_bisect_status__() {
    if [ ! -f ".git/BISECT_LOG" ]; then
        echo "No bisect session in progress"
        return 0
    fi
    
    echo
    __jwgit_h__ "Bisect Status"
    
    # Show current commit being tested
    local current_commit
    current_commit=$(git rev-parse --short HEAD)
    __jwgit_kv__ "Testing commit:" "$current_commit"
    __jwgit_kv__ "Commit info:" "$(git log -1 --oneline)"
    
    # Show bisect log
    if [ -f ".git/BISECT_LOG" ]; then
        echo
        echo "Bisect progress:"
        local good_commits
        local bad_commits
        good_commits=$(grep -c "^git bisect good" .git/BISECT_LOG 2>/dev/null)
        bad_commits=$(grep -c "^git bisect bad" .git/BISECT_LOG 2>/dev/null)
        
        echo "  Good commits marked: $good_commits"
        echo "  Bad commits marked: $bad_commits"
    fi
    
    # Show remaining commits to test
    local remaining
    remaining=$(git bisect visualize --oneline 2>/dev/null | wc -l || echo "unknown")
    if [ "$remaining" != "unknown" ] && [ "$remaining" -gt 0 ]; then
        echo "  Commits remaining: ~$remaining"
    fi
    
    echo
    echo "Next steps:"
    echo "  - Test current commit for the bug"
    echo "  - Run 'jwgit_bisect good' if commit is good"
    echo "  - Run 'jwgit_bisect bad' if commit is bad"
    echo "  - Run 'jwgit_bisect skip' if commit is untestable"
    echo "  - Run 'jwgit_bisect reset' to end session"
}


jwgit_reflog() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwgit_reflog [branch|HEAD] [options]"
        echo "Examples:"
        echo "  jwgit_reflog                   # Show HEAD reflog"
        echo "  jwgit_reflog main              # Show main branch reflog"
        echo "  jwgit_reflog --all             # Show all reflogs"
        echo "  jwgit_reflog -10               # Show last 10 entries"
        echo "  jwgit_reflog --since=\"1 week\"  # Show entries from last week"
        echo
        echo "Reflog shows the history of where HEAD (or branch) has been."
        echo "Useful for recovering lost commits or understanding recent changes."
        echo
        return 0
    fi

    local REF="HEAD"
    local -a OPTS=()
    local LIMIT=""
    local SHOW_ALL=""
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            --all)
                SHOW_ALL="--all"
                shift
                ;;
            --since=*|--until=*)
                OPTS+=("$1")
                shift
                ;;
            --since|--until)
                OPTS+=("$1" "$2")
                shift 2
                ;;
            -[0-9]*)
                LIMIT="$1"
                shift
                ;;
            -*)
                OPTS+=("$1")
                shift
                ;;
            *)
                REF="$1"
                shift
                ;;
        esac
    done
    
    echo "📚 Git Reflog"
    echo "=================================================="
    echo
    
    if [ -n "$SHOW_ALL" ]; then
        __jwgit_h__ "All Reflogs"
        
        # Show available reflogs
        echo "Available reflogs:"
        local ref_name entry_count
        git reflog --all --format="%gd" | cut -d'@' -f1 | sort -u | while read -r ref_name; do
            if [ -n "$ref_name" ]; then
                entry_count=$(git reflog "$ref_name" | wc -l 2>/dev/null || echo "0")
                echo "  $ref_name ($entry_count entries)"
            fi
        done
        echo
        
        # Show combined reflog
        __jwgit_h__ "Combined Reflog Entries"
        local -a CMD=(reflog --all)
        [ -n "$LIMIT" ] && CMD+=("$LIMIT")   # no default cap; pass -N to limit
        CMD+=("${OPTS[@]}")
        git "${CMD[@]}" --format="%C(yellow)%gd%C(reset) %C(green)(%cr)%C(reset) %gs %C(blue)%h%C(reset) %s"
        
    else
        # Validate reference
        if ! git show-ref --verify --quiet "refs/heads/$REF" 2>/dev/null && [ "$REF" != "HEAD" ]; then
            if ! git rev-parse --verify "$REF" >/dev/null 2>&1; then
                echo "❌ Invalid reference: $REF"
                echo
                echo "Available branches:"
                git branch --format="  %(refname:short)" | head -10
                echo "  HEAD"
                return 1
            fi
        fi
        
        __jwgit_h__ "Reflog for: $REF"
        
        # Show reflog statistics
        local total_entries
        total_entries=$(git reflog "$REF" | wc -l 2>/dev/null || echo "0")
        echo "Total reflog entries: $total_entries"
        
        if [ "$total_entries" -eq 0 ]; then
            echo "No reflog entries found for $REF"
            return 0
        fi
        
        # Show current position
        if [ "$REF" = "HEAD" ]; then
            local current_branch
            current_branch=$(git branch --show-current 2>/dev/null)
            if [ -n "$current_branch" ]; then
                echo "Current branch: $current_branch"
            else
                echo "Current: $(git rev-parse --short HEAD) (detached)"
            fi
        fi
        echo
        
        # Build reflog command
        local -a CMD=(reflog "$REF")
        [ -n "$LIMIT" ] && CMD+=("$LIMIT")   # no default cap; pass -N to limit
        CMD+=("${OPTS[@]}")
        
        # Show reflog with enhanced formatting
        __jwgit_h__ "Reflog Entries"
        echo "Format: [ref] (time) action commit_hash commit_message"
        echo
        
        git "${CMD[@]}" --format="%C(yellow)%gd%C(reset) %C(green)(%cr)%C(reset) %gs %C(blue)%h%C(reset) %s"
    fi
    
    echo
    __jwgit_h__ "Reflog Help"
    echo "Reflog entries show:"
    echo "  - Branch switches (checkout)"
    echo "  - Commits and amends"
    echo "  - Merges and rebases"
    echo "  - Resets and other ref updates"
    echo
    echo "To recover a lost commit:"
    echo "  1. Find the commit hash in reflog"
    echo "  2. Create a branch: git branch recovery <hash>"
    echo "  3. Or cherry-pick: jwgit_cherry-pick <hash>"
    echo
    echo "💡 Reflog entries expire after 90 days by default"
    echo
}
