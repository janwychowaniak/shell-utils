# shellcheck shell=bash


# ---------------------------------------------------------------------------------
# table of contents
# ---------------------------------------------------------------------------------

jwgit_toc() {
    echo
    echo "   blast radius:  🟢 tylko odczyt   🔵 tworzy   ⚪ zmiana stanu / transfer   🔴 kasuje (destructive)"
    echo
    echo " -----------------------------  repository management"
    echo " - 🔵 jwgit_init"
    echo " - 🔵 jwgit_clone"
    echo " - ⚪ jwgit_remote"
    echo
    echo " -----------------------------  branch operations"
    echo " - ⚪ jwgit_branch"
    echo " - ⚪ jwgit_checkout"
    echo " - ⚪ jwgit_merge"
    echo " - ⚪ jwgit_rebase"
    echo
    echo " -----------------------------  staging & commits"
    echo " - ⚪ jwgit_add"
    echo " - 🔵 jwgit_commit"
    echo " - ⚪ jwgit_stash"
    echo " - 🔴 jwgit_reset"
    echo
    echo " -----------------------------  remote operations"
    echo " - ⚪ jwgit_push"
    echo " - ⚪ jwgit_pull"
    echo " - ⚪ jwgit_fetch"
    echo
    echo " -----------------------------  history & information"
    echo " - 🟢 jwgit_log"
    echo " - 🟢 jwgit_status"
    echo " - 🟢 jwgit_diff"
    echo " - 🟢 jwgit_blame"
    echo
    echo " -----------------------------  maintenance & cleanup"
    echo " - 🔴 jwgit_clean"
    echo " - 🔴 jwgit_prune"
    echo " - 🔴 jwgit_gc"
    echo
    echo " -----------------------------  advanced operations"
    echo " - ⚪ jwgit_cherry-pick"
    echo " - ⚪ jwgit_bisect"
    echo " - 🟢 jwgit_reflog"
    echo
}



# ---------------------------------------------------------------------------------
# repository management
# ---------------------------------------------------------------------------------

jwgit_init() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwgit_init [directory] [--bare]"
        echo "Examples:"
        echo "  jwgit_init .                  # Initialize current directory"
        echo "  jwgit_init myproject          # Initialize new directory"
        echo "  jwgit_init myrepo --bare      # Initialize bare repository"
        echo
        return 1
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
    
    if [ $? -eq 0 ]; then
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
    if [ $# -eq 0 ]; then
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
        return 1
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
            echo "---[ Repository Info ]------------------------------"
            echo "Remote origin: $(git -C "$DIR" remote get-url origin 2>/dev/null || echo 'Not set')"
            echo "Current branch: $(git -C "$DIR" branch --show-current 2>/dev/null || echo 'Unknown')"
            echo "Latest commit: $(git -C "$DIR" log -1 --oneline 2>/dev/null || echo 'No commits')"
            echo "Total commits: $(git -C "$DIR" rev-list --count HEAD 2>/dev/null || echo '0')"
            local branch_count
            branch_count=$(git -C "$DIR" branch -r 2>/dev/null | wc -l)
            echo "Remote branches: $branch_count"
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
    if [ $# -eq 0 ]; then
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
        return 1
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
            
            while IFS= read -r remote; do
                echo "---[ Remote: $remote ]------------------------------"
                local fetch_url
                local push_url
                fetch_url=$(git remote get-url "$remote" 2>/dev/null)
                push_url=$(git remote get-url --push "$remote" 2>/dev/null)
                
                echo "Fetch URL: $fetch_url"
                if [ "$push_url" != "$fetch_url" ]; then
                    echo "Push URL:  $push_url"
                fi
                
                # Show remote branches
                echo "Branches:"
                git branch -r | grep "^  $remote/" | sed 's/^/  /' | head -10
                
                local branch_count
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


# ---------------------------------------------------------------------------------
# branch operations
# ---------------------------------------------------------------------------------

jwgit_branch() {
    if [ $# -eq 0 ]; then
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
        return 1
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
                echo "---[ Remote Branches ]------------------------------"
                git branch -r --format="  %(refname:short)%(if)%(upstream)%(then) -> %(upstream:short)%(end)"
            elif [ "$BRANCH_NAME" = "--all" ] || [ "$BRANCH_NAME" = "-a" ]; then
                echo "---[ Local Branches ]-------------------------------"
                git branch --format="%(if)%(HEAD)%(then)* %(else)  %(end)%(refname:short)"
                echo
                echo "---[ Remote Branches ]------------------------------"
                git branch -r --format="  %(refname:short)"
            else
                echo "---[ Local Branches ]-------------------------------"
                git branch --format="%(if)%(HEAD)%(then)* %(else)  %(end)%(refname:short)%(if)%(upstream)%(then) -> %(upstream:short)%(end)"
                
                local current_branch
                current_branch=$(git branch --show-current)
                if [ -n "$current_branch" ]; then
                    echo
                    echo "Current branch: $current_branch"
                    
                    # Show branch info
                    local upstream
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
                            
                            if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
                                echo "Status: $ahead ahead, $behind behind"
                            else
                                echo "Status: up to date"
                            fi
                        fi
                    else
                        echo "Upstream: (not set)"
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
            
            if [ $? -eq 0 ]; then
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
                local upstream
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
    if [ $# -eq 0 ]; then
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
        return 1
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
            local upstream
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
    if [ $# -eq 0 ]; then
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
        return 1
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
    echo "---[ Commits to be merged ]-------------------------"
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
        echo "---[ Merge Summary ]--------------------------------"
        echo "Merged: $BRANCH -> $current_branch"
        echo "Latest commit: $(git log -1 --oneline)"
        
    else
        echo
        echo "❌ Merge failed due to conflicts!"
        echo
        echo "---[ Conflicted Files ]-----------------------------"
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
    if [ $# -eq 0 ]; then
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
        return 1
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
        echo "---[ Commits to be rebased ]------------------------"
        git log --oneline "$TARGET..HEAD" | head -10 | sed 's/^/  /'
        local commit_count
        commit_count=$(git rev-list --count "$TARGET..HEAD" 2>/dev/null || echo "0")
        echo "Total commits: $commit_count"
        
        if [ "$commit_count" -gt 10 ]; then
            echo "  ... and $((commit_count - 10)) more commits"
        fi
    else
        echo "---[ Rebase Information ]---------------------------"
        echo "Target: $TARGET"
        echo "Current branch: $current_branch"
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
        echo "---[ Rebase Summary ]-------------------------------"
        echo "Rebased: $current_branch onto $TARGET"
        echo "Latest commit: $(git log -1 --oneline)"
        
    else
        echo
        echo "❌ Rebase failed due to conflicts!"
        echo
        echo "---[ Conflicted Files ]-----------------------------"
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


# ---------------------------------------------------------------------------------
# staging & commits
# ---------------------------------------------------------------------------------

jwgit_add() {
    if [ $# -eq 0 ]; then
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
        return 1
    fi

    # Standalone modes (no pathspec needed)
    case $1 in
        --update|-u)
            echo "Adding all modified tracked files..."
            if git add --update; then
                echo "✅ Updated files added to staging area"
                jwgit_status
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
                    jwgit_status
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
        echo "---[ File Status ]----------------------------------"
        git status --porcelain "$1" | sed 's/^/  /'
        echo
    elif [ "$1" = "." ]; then
        echo "---[ Changes to be added ]--------------------------"
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
        echo "---[ Staging Area Status ]-------------------------"
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
    if [ $# -eq 0 ]; then
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
        return 1
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
        
        if [ $? -eq 0 ]; then
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
    echo "---[ Commit Summary ]-------------------------------"
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
        echo "---[ Commit Information ]---------------------------"
        echo "Commit: $(git log -1 --oneline)"
        echo "Author: $(git log -1 --format='%an <%ae>')"
        echo "Date: $(git log -1 --format='%ad' --date=format:'%Y-%m-%d %H:%M:%S')"
        
        # Show files changed
        local files_changed
        files_changed=$(git diff --name-only HEAD~1 HEAD | wc -l)
        echo "Files changed: $files_changed"
        
        # Show branch status
        local current_branch
        current_branch=$(git branch --show-current)
        if [ -n "$current_branch" ]; then
            echo "Branch: $current_branch"
            
            # Show ahead/behind status if upstream exists
            local upstream
            upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
            if [ -n "$upstream" ]; then
                local ahead_behind
                ahead_behind=$(git rev-list --left-right --count "$current_branch...$upstream" 2>/dev/null)
                if [ -n "$ahead_behind" ]; then
                    local ahead
                    local behind
                    ahead=$(echo "$ahead_behind" | cut -f1)
                    behind=$(echo "$ahead_behind" | cut -f2)
                    echo "Status: $ahead ahead, $behind behind $upstream"
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
    if [ $# -eq 0 ]; then
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
        return 1
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
            git stash apply "$STASH_REF"
            
            if [ $? -eq 0 ]; then
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
            echo "---[ Stash Info ]-----------------------------------"
            git stash list | grep -F "$STASH_REF" | sed 's/^/  /'
            echo
            
            echo "---[ Changed Files ]--------------------------------"
            git stash show --name-status "$STASH_REF" | sed 's/^/  /'
            echo
            
            echo "---[ Diff Summary ]---------------------------------"
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
                git stash drop "$STASH_REF"
                if [ $? -eq 0 ]; then
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
                git stash clear
                if [ $? -eq 0 ]; then
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
    if [ $# -eq 0 ]; then
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
        return 1
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
    echo "---[ Reset Information ]----------------------------"
    echo "Current HEAD: $(git rev-parse --short HEAD) ($(git log -1 --oneline))"
    echo "Reset target: $(git rev-parse --short "$TARGET") ($(git log -1 --oneline "$TARGET"))"
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
        echo "---[ Reset Summary ]--------------------------------"
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


# ---------------------------------------------------------------------------------
# remote operations
# ---------------------------------------------------------------------------------

jwgit_push() {
    if [ $# -eq 0 ]; then
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
            
            local upstream
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
        return 1
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
        local upstream
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
    echo "Remote: $REMOTE"
    if [ -n "$BRANCH" ]; then
        echo "Branch: $BRANCH"
    fi
    if [ ${#OPTS[@]} -gt 0 ]; then
        echo "Options: ${OPTS[*]}"
    fi
    if [ -n "$SET_UPSTREAM" ]; then
        echo "Setting upstream: $REMOTE/$BRANCH"
    fi
    if [ -n "$FORCE" ]; then
        echo "Force push: $FORCE"
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
        echo "---[ Commits to Push ]------------------------------"
        
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
        echo "---[ Push Summary ]---------------------------------"
        echo "Remote: $REMOTE"
        if [ -n "$BRANCH" ]; then
            echo "Branch: $BRANCH"
            
            # Update upstream info
            if [ -n "$SET_UPSTREAM" ]; then
                echo "Upstream set: $REMOTE/$BRANCH"
            fi
            
            # Show final status
            local upstream
            upstream=$(git rev-parse --abbrev-ref "$BRANCH@{upstream}" 2>/dev/null)
            if [ -n "$upstream" ]; then
                echo "Status: up to date with $upstream"
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
    if [ $# -eq 0 ]; then
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
            
            local upstream
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
        return 1
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
        local upstream
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
    echo "Remote: $REMOTE"
    if [ -n "$BRANCH" ] && [ -z "$HAS_ALL" ]; then
        echo "Branch: $BRANCH"
    fi
    if [ ${#OPTS[@]} -gt 0 ]; then
        echo "Options: ${OPTS[*]}"
    fi
    if [ -n "$REBASE" ]; then
        echo "Mode: Rebase (instead of merge)"
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
        echo "---[ Changes to Pull ]------------------------------"
        
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
        echo "---[ Pull Summary ]---------------------------------"
        echo "Remote: $REMOTE"
        if [ -n "$BRANCH" ]; then
            echo "Branch: $BRANCH"
        fi
        echo "Latest commit: $(git log -1 --oneline)"
        
        # Show final status
        if [ -n "$current_branch" ]; then
            local upstream
            upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
            if [ -n "$upstream" ]; then
                echo "Status: up to date with $upstream"
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
    if [ $# -eq 0 ]; then
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
            local upstream
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
        return 1
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
        echo "Mode: Fetch from all remotes"
    else
        echo "Remote: $REMOTE"
    fi
    if [ ${#OPTS[@]} -gt 0 ]; then
        echo "Options: ${OPTS[*]}"
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
    echo "---[ Before Fetch ]---------------------------------"
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    
    if [ -n "$current_branch" ]; then
        local upstream
        upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
        if [ -n "$upstream" ]; then
            echo "Current branch: $current_branch"
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
            echo "Current branch: $current_branch (no upstream)"
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
        echo "---[ After Fetch ]----------------------------------"
        
        # Show updated status for current branch
        if [ -n "$current_branch" ]; then
            local upstream
            upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
            if [ -n "$upstream" ]; then
                echo "Current branch: $current_branch"
                echo "Upstream: $upstream"
                
                # Show updated ahead/behind status
                local ahead_behind
                ahead_behind=$(git rev-list --left-right --count "$current_branch...$upstream" 2>/dev/null)
                if [ -n "$ahead_behind" ]; then
                    local ahead
                    local behind
                    ahead=$(echo "$ahead_behind" | cut -f1)
                    behind=$(echo "$ahead_behind" | cut -f2)
                    echo "Status: $ahead ahead, $behind behind"
                    
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
        echo "---[ Remote Branches ]------------------------------"
        if [ -n "$REMOTE" ]; then
            git branch -r | grep "^  $REMOTE/" | head -10 | sed 's/^/  /'
            local remote_branch_count
            remote_branch_count=$(git branch -r | grep -c "^  $REMOTE/" || echo "0")
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
    if [ $# -eq 0 ]; then
        echo "Usage: jwgit_log [options] [branch|commit] [-- file]"
        echo "Examples:"
        echo "  jwgit_log                      # Show recent commits"
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
        return 1
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
    
    # Set default limit if not specified
    if [ -z "$LIMIT" ] && [ ${#OPTS[@]} -eq 0 ]; then
        LIMIT="-20"
    fi
    
    echo "📜 Git Commit History"
    echo "=================================================="
    echo
    
    # Show repository info
    echo "---[ Repository Info ]------------------------------"
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
    echo "---[ Commit History ]-------------------------------"
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


jwgit_status() {
    echo "📊 Git Repository Status"
    echo "=================================================="
    echo
    
    # Repository info
    echo "---[ Repository Info ]------------------------------"
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$repo_root" ]; then
        echo "Repository: $(basename "$repo_root")"
        echo "Location: $repo_root"
    else
        echo "❌ Not in a git repository"
        return 1
    fi
    
    # Branch information
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$current_branch" ]; then
        echo "Current branch: $current_branch"
        
        # Upstream information
        local upstream
        upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
        if [ -n "$upstream" ]; then
            echo "Upstream: $upstream"
            
            # Ahead/behind status
            local ahead_behind
            ahead_behind=$(git rev-list --left-right --count "$current_branch...$upstream" 2>/dev/null)
            if [ -n "$ahead_behind" ]; then
                local ahead
                local behind
                ahead=$(echo "$ahead_behind" | cut -f1)
                behind=$(echo "$ahead_behind" | cut -f2)
                
                if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
                    echo "Status: $ahead ahead, $behind behind"
                else
                    echo "Status: up to date"
                fi
            fi
        else
            echo "Upstream: (not set)"
        fi
    else
        local current_commit
        current_commit=$(git rev-parse --short HEAD 2>/dev/null)
        if [ -n "$current_commit" ]; then
            echo "HEAD: $current_commit (detached)"
        else
            echo "HEAD: (no commits yet)"
        fi
    fi
    
    # Latest commit
    local latest_commit
    latest_commit=$(git log -1 --oneline 2>/dev/null)
    if [ -n "$latest_commit" ]; then
        echo "Latest commit: $latest_commit"
    fi
    echo
    
    # Working directory status
    echo "---[ Working Directory ]----------------------------"
    
    # Get status counts
    local staged_count
    local modified_count
    local untracked_count
    local deleted_count
    
    staged_count=$(git status --porcelain | grep -c "^[MADRC]" || echo "0")
    modified_count=$(git status --porcelain | grep -c "^ [MD]" || echo "0")
    untracked_count=$(git status --porcelain | grep -c "^??" || echo "0")
    deleted_count=$(git status --porcelain | grep -c "^ D\|^D " || echo "0")
    
    echo "Staged files: $staged_count"
    echo "Modified files: $modified_count"
    echo "Untracked files: $untracked_count"
    echo "Deleted files: $deleted_count"
    
    # Show detailed status if there are changes
    if [ "$staged_count" -gt 0 ] || [ "$modified_count" -gt 0 ] || [ "$untracked_count" -gt 0 ]; then
        echo
        
        # Staged files
        if [ "$staged_count" -gt 0 ]; then
            echo "---[ Staged Files ]---------------------------------"
            git status --porcelain | grep "^[MADRC]" | head -10 | while read -r line; do
                local status
                local file
                status=$(echo "$line" | cut -c1-2)
                file=$(echo "$line" | cut -c4-)
                
                case $status in
                    A*) echo "  ✅ $file (new file)" ;;
                    M*) echo "  📝 $file (modified)" ;;
                    D*) echo "  🗑️  $file (deleted)" ;;
                    R*) echo "  🔄 $file (renamed)" ;;
                    C*) echo "  📋 $file (copied)" ;;
                    *) echo "  $status $file" ;;
                esac
            done
            
            if [ "$staged_count" -gt 10 ]; then
                echo "  ... and $((staged_count - 10)) more files"
            fi
            echo
        fi
        
        # Modified files
        if [ "$modified_count" -gt 0 ]; then
            echo "---[ Modified Files ]-------------------------------"
            git status --porcelain | grep "^ [MD]" | head -10 | while read -r line; do
                local status
                local file
                status=$(echo "$line" | cut -c1-2)
                file=$(echo "$line" | cut -c4-)
                
                case $status in
                    " M") echo "  📝 $file (modified)" ;;
                    " D") echo "  🗑️  $file (deleted)" ;;
                    *) echo "  $status $file" ;;
                esac
            done
            
            if [ "$modified_count" -gt 10 ]; then
                echo "  ... and $((modified_count - 10)) more files"
            fi
            echo
        fi
        
        # Untracked files
        if [ "$untracked_count" -gt 0 ]; then
            echo "---[ Untracked Files ]------------------------------"
            git status --porcelain | grep "^??" | head -10 | while read -r line; do
                local file
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
        echo "---[ Stashes ]--------------------------------------"
        echo "Stashed changes: $stash_count"
        git stash list | head -3 | sed 's/^/  /'
        if [ "$stash_count" -gt 3 ]; then
            echo "  ... and $((stash_count - 3)) more stashes"
        fi
        echo
    fi
    
    # Recent activity
    echo "---[ Recent Activity ]------------------------------"
    echo "Recent commits (last 5):"
    git log --oneline -5 | sed 's/^/  /' 2>/dev/null || echo "  (no commits)"
    echo
    
    # Remotes
    echo "---[ Remotes ]--------------------------------------"
    if git remote | grep -q .; then
        git remote -v | sed 's/^/  /'
    else
        echo "  (no remotes configured)"
    fi
    echo
    
    # Quick actions
    echo "---[ Quick Actions ]--------------------------------"
    if [ "$staged_count" -gt 0 ]; then
        echo "💡 Ready to commit: jwgit_commit"
    elif [ "$modified_count" -gt 0 ] || [ "$untracked_count" -gt 0 ]; then
        echo "💡 Stage changes: jwgit_add ."
    fi
    
    if [ -n "$upstream" ]; then
        local behind
        behind=$(git rev-list --count HEAD.."$upstream" 2>/dev/null || echo "0")
        if [ "$behind" -gt 0 ]; then
            echo "💡 Pull updates: jwgit_pull"
        fi
        
        local ahead
        ahead=$(git rev-list --count "$upstream"..HEAD 2>/dev/null || echo "0")
        if [ "$ahead" -gt 0 ]; then
            echo "💡 Push changes: jwgit_push"
        fi
    fi
    echo
}


jwgit_diff() {
    if [ $# -eq 0 ]; then
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
        return 1
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
    
    echo "---[ Diff Info ]------------------------------------"
    echo "Comparing: $diff_description"
    if [ ${#FILES[@]} -gt 0 ]; then
        echo "File filter: ${FILES[*]}"
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
    echo "---[ Summary ]--------------------------------------"
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
        
        echo "Files changed: $files_changed"
        echo "Insertions: +$insertions"
        echo "Deletions: -$deletions"
        echo
        
        # Show file list with changes
        echo "---[ Changed Files ]--------------------------------"
        git "${SUM[@]}" --name-status | while read -r status file; do
            case $status in
                A) echo "  ✅ $file (added)" ;;
                M) echo "  📝 $file (modified)" ;;
                D) echo "  🗑️  $file (deleted)" ;;
                R*) echo "  🔄 $file (renamed)" ;;
                C*) echo "  📋 $file (copied)" ;;
                *) echo "  $status $file" ;;
            esac
        done
        echo
    else
        echo "No changes to show"
        return 0
    fi
    
    # Show the actual diff
    if [ -z "$STAT_ONLY" ] && [ -z "$NAME_ONLY" ]; then
        echo "---[ Diff Content ]---------------------------------"
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
        echo "---[ Diff Output ]----------------------------------"
        git "${DIFF[@]}"
    fi
    
    echo
    echo "💡 Use 'jwgit_diff --help' for more options"
    echo
}


jwgit_blame() {
    if [ $# -eq 0 ]; then
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
        return 1
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
    echo "---[ File Info ]------------------------------------"
    echo "File: $FILE"
    echo "Size: $(wc -l < "$FILE") lines"
    
    # Show recent commits affecting this file
    echo "Recent commits affecting this file:"
    git log --oneline -5 -- "$FILE" | sed 's/^/  /' 2>/dev/null || echo "  (no commits found)"
    echo
    
    # Show blame with enhanced formatting
    echo "---[ Blame Output ]---------------------------------"
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
    echo "---[ Blame Summary ]--------------------------------"
    
    # Show author statistics
    echo "Authors contributing to this file:"
    git blame --porcelain "$FILE" 2>/dev/null | grep "^author " | sort | uniq -c | sort -rn | head -10 | while read -r count author_line; do
        local author
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
    if [ $# -eq 0 ]; then
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
            untracked_count=$(git status --porcelain | grep -c "^??" || echo "0")
            if [ "$untracked_count" -gt 10 ]; then
                echo "  ... and $((untracked_count - 10)) more files"
            fi
        else
            echo "  (no untracked files)"
        fi
        echo
        return 1
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
    echo "---[ Clean Preview ]--------------------------------"
    
    local clean_cmd="git clean"
    if [ -n "$DRY_RUN" ]; then
        clean_cmd="$clean_cmd -n"
    fi
    if [ -n "$DIRECTORIES" ]; then
        clean_cmd="$clean_cmd -d"
    fi
    if [ -n "$IGNORED" ]; then
        clean_cmd="$clean_cmd -x"
    fi
    
    local files_to_clean
    files_to_clean=$(eval "$clean_cmd" 2>/dev/null)
    
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
    echo "---[ Clean Options ]--------------------------------"
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
        echo "---[ To Actually Clean ]----------------------------"
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
    echo "---[ Cleaning ]-------------------------------------"
    
    local final_cmd="git clean"
    if [ -n "$FORCE" ]; then
        final_cmd="$final_cmd -f"
    fi
    if [ -n "$DIRECTORIES" ]; then
        final_cmd="$final_cmd -d"
    fi
    if [ -n "$IGNORED" ]; then
        final_cmd="$final_cmd -x"
    fi
    if [ -n "$INTERACTIVE" ]; then
        final_cmd="$final_cmd -i"
    fi
    
    eval "$final_cmd"
    
    local clean_result=$?
    
    if [ $clean_result -eq 0 ]; then
        echo
        echo "✅ Clean completed successfully!"
        echo
        echo "---[ Final Status ]---------------------------------"
        local remaining_untracked
        remaining_untracked=$(git status --porcelain | grep -c "^??" || echo "0")
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
    echo "---[ Repository Size Before ]----------------------"
    local size_before
    size_before=$(du -sh .git 2>/dev/null | cut -f1 || echo "unknown")
    echo "Repository size: $size_before"
    echo
    
    echo "---[ Pruning Remote Branches ]---------------------"
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
    
    echo "---[ Cleaning Reflog ]------------------------------"
    echo "Cleaning reflog entries older than 30 days..."
    git reflog expire --expire=30.days.ago --all
    echo
    
    echo "---[ Garbage Collection ]---------------------------"
    echo "Running garbage collection..."
    git gc --prune=now --aggressive
    echo
    
    echo "---[ Repository Size After ]-----------------------"
    local size_after
    size_after=$(du -sh .git 2>/dev/null | cut -f1 || echo "unknown")
    echo "Repository size: $size_after"
    echo
    
    echo "---[ Maintenance Summary ]--------------------------"
    echo "Before: $size_before"
    echo "After:  $size_after"
    
    # Show object count
    local object_count
    object_count=$(git count-objects -v | grep "count" | cut -d' ' -f2 || echo "unknown")
    echo "Objects: $object_count"
    
    # Show pack info
    local pack_count
    pack_count=$(git count-objects -v | grep "packs" | cut -d' ' -f2 || echo "0")
    echo "Packs: $pack_count"
    
    echo
    echo "✅ Repository maintenance completed!"
    echo
}


jwgit_gc() {
    echo "🗑️  Git Garbage Collection"
    echo "=================================================="
    echo
    
    # Show repository info before cleanup
    echo "---[ Before Cleanup ]-------------------------------"
    echo "Repository statistics:"
    git count-objects -v | while read -r line; do
        echo "  $line"
    done
    echo
    
    local repo_size_before
    repo_size_before=$(du -sh .git 2>/dev/null | cut -f1 || echo "unknown")
    echo "Repository size: $repo_size_before"
    echo
    
    echo "Garbage collection will:"
    echo "  - Remove unreachable objects"
    echo "  - Compress object database"
    echo "  - Optimize pack files"
    echo "  - Clean up temporary files"
    echo
    echo -n "Continue with garbage collection? [y/N] "
    read -r response
    
    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        echo "Garbage collection cancelled"
        return 1
    fi
    
    echo
    echo "---[ Running Garbage Collection ]-------------------"
    
    # Run garbage collection with progress
    echo "Phase 1: Cleaning up loose objects..."
    git gc --prune=now
    
    echo
    echo "Phase 2: Aggressive optimization..."
    git gc --aggressive
    
    echo
    echo "---[ After Cleanup ]--------------------------------"
    echo "Repository statistics:"
    git count-objects -v | while read -r line; do
        echo "  $line"
    done
    echo
    
    local repo_size_after
    repo_size_after=$(du -sh .git 2>/dev/null | cut -f1 || echo "unknown")
    echo "Repository size: $repo_size_after"
    echo
    
    echo "---[ Cleanup Summary ]------------------------------"
    echo "Size before: $repo_size_before"
    echo "Size after:  $repo_size_after"
    
    # Calculate objects cleaned up
    local objects_after
    objects_after=$(git count-objects | cut -d' ' -f1 || echo "0")
    echo "Loose objects remaining: $objects_after"
    
    echo
    echo "✅ Garbage collection completed!"
    echo "💡 Repository is now optimized for better performance"
    echo
}


# ---------------------------------------------------------------------------------
# advanced operations
# ---------------------------------------------------------------------------------

jwgit_cherry-pick() {
    if [ $# -eq 0 ]; then
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
        return 1
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
    echo "---[ Commit to Cherry-pick ]------------------------"
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
    
    echo "---[ Cherry-pick Operation ]------------------------"
    echo "Target branch: $current_branch"
    echo "Commit: $(git log -1 --oneline "$COMMIT")"
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
        echo "---[ Cherry-pick Summary ]--------------------------"
        echo "Branch: $current_branch"
        echo "Cherry-picked: $(git log -1 --oneline "$COMMIT")"
        echo "New commit: $(git log -1 --oneline)"
        
    else
        echo
        echo "❌ Cherry-pick failed due to conflicts!"
        echo
        echo "---[ Conflicted Files ]-----------------------------"
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
    if [ $# -eq 0 ]; then
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
        return 1
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
            if [ -d ".git/BISECT_LOG" ]; then
                echo "⚠️  Bisect session already in progress"
                echo "Use 'jwgit_bisect reset' to end current session first"
                return 1
            fi
            
            echo "Starting bisect session..."
            git bisect start
            
            if [ $? -eq 0 ]; then
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
            if [ ! -d ".git/BISECT_LOG" ]; then
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
            if [ ! -d ".git/BISECT_LOG" ]; then
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
            if [ ! -d ".git/BISECT_LOG" ]; then
                echo "❌ No bisect session in progress"
                echo "Start one with: jwgit_bisect start"
                return 1
            fi
            
            echo "Skipping current commit..."
            git bisect skip
            
            if [ $? -eq 0 ]; then
                echo "✅ Commit skipped"
                __jwgit_bisect_status__
            else
                echo "❌ Failed to skip commit"
                return 1
            fi
            ;;
            
        reset)
            if [ ! -d ".git/BISECT_LOG" ]; then
                echo "No bisect session in progress"
                return 0
            fi
            
            echo "Ending bisect session..."
            git bisect reset
            
            if [ $? -eq 0 ]; then
                echo "✅ Bisect session ended"
                echo "Returned to original branch"
            else
                echo "❌ Failed to reset bisect session"
                return 1
            fi
            ;;
            
        run)
            if [ ! -d ".git/BISECT_LOG" ]; then
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
                git bisect run $ARGS
                
                if [ $? -eq 0 ]; then
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
    if [ ! -d ".git/BISECT_LOG" ]; then
        echo "No bisect session in progress"
        return 0
    fi
    
    echo
    echo "---[ Bisect Status ]--------------------------------"
    
    # Show current commit being tested
    local current_commit
    current_commit=$(git rev-parse --short HEAD)
    echo "Testing commit: $current_commit"
    echo "Commit info: $(git log -1 --oneline)"
    
    # Show bisect log
    if [ -f ".git/BISECT_LOG" ]; then
        echo
        echo "Bisect progress:"
        local good_commits
        local bad_commits
        good_commits=$(grep -c "^git bisect good" .git/BISECT_LOG 2>/dev/null || echo "0")
        bad_commits=$(grep -c "^git bisect bad" .git/BISECT_LOG 2>/dev/null || echo "0")
        
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
    if [ $# -eq 0 ]; then
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
        return 1
    fi

    local REF="HEAD"
    local OPTIONS=""
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
                OPTIONS="$OPTIONS $1"
                shift
                ;;
            --since|--until)
                OPTIONS="$OPTIONS $1 $2"
                shift 2
                ;;
            -[0-9]*)
                LIMIT="$1"
                shift
                ;;
            -*)
                OPTIONS="$OPTIONS $1"
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
        echo "---[ All Reflogs ]----------------------------------"
        
        # Show available reflogs
        echo "Available reflogs:"
        git reflog --all --format="%gd" | cut -d'@' -f1 | sort -u | while read -r ref_name; do
            if [ -n "$ref_name" ]; then
                local entry_count
                entry_count=$(git reflog "$ref_name" | wc -l 2>/dev/null || echo "0")
                echo "  $ref_name ($entry_count entries)"
            fi
        done
        echo
        
        # Show combined reflog
        echo "---[ Combined Reflog Entries ]---------------------"
        local reflog_cmd="git reflog --all"
        
        if [ -n "$LIMIT" ]; then
            reflog_cmd="$reflog_cmd $LIMIT"
        else
            reflog_cmd="$reflog_cmd -20"
        fi
        
        if [ -n "$OPTIONS" ]; then
            reflog_cmd="$reflog_cmd $OPTIONS"
        fi
        
        eval "$reflog_cmd" --format="%C(yellow)%gd%C(reset) %C(green)(%cr)%C(reset) %gs %C(blue)%h%C(reset) %s"
        
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
        
        echo "---[ Reflog for: $REF ]-----------------------------"
        
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
        local reflog_cmd="git reflog $REF"
        
        if [ -n "$LIMIT" ]; then
            reflog_cmd="$reflog_cmd $LIMIT"
        else
            reflog_cmd="$reflog_cmd -20"
        fi
        
        if [ -n "$OPTIONS" ]; then
            reflog_cmd="$reflog_cmd $OPTIONS"
        fi
        
        # Show reflog with enhanced formatting
        echo "---[ Reflog Entries ]-------------------------------"
        echo "Format: [ref] (time) action commit_hash commit_message"
        echo
        
        eval "$reflog_cmd" --format="%C(yellow)%gd%C(reset) %C(green)(%cr)%C(reset) %gs %C(blue)%h%C(reset) %s"
    fi
    
    echo
    echo "---[ Reflog Help ]----------------------------------"
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
