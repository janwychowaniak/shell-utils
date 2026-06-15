# shellcheck shell=bash


# ---------------------------------------------------------------------------------
# table of contents
# ---------------------------------------------------------------------------------

jwdeb_toc() {
    echo
    echo "   blast radius:  🟢 tylko odczyt   🔵 tworzy   ⚪ zmiana stanu / transfer   🔴 kasuje (destructive)"
    echo
    echo " -----------------------------  package search & information"
    echo " - 🟢 jwdeb_search"
    echo " - 🟢 jwdeb_info"
    echo " - 🟢 jwdeb_policy"
    echo " - 🟢 jwdeb_depends"
    echo " - 🟢 jwdeb_files"
    echo " - 🟢 jwdeb_which"
    echo
    echo " -----------------------------  package management"
    echo " - 🔵 jwdeb_install"
    echo " - 🔴 jwdeb_remove"
    echo " - 🔴 jwdeb_purge"
    echo " - ⚪ jwdeb_reinstall"
    echo " - 🔵 jwdeb_download"
    echo " - ⚪ jwdeb_hold"
    echo " - ⚪ jwdeb_unhold"
    echo
    echo " -----------------------------  system updates"
    echo " - ⚪ jwdeb_update"
    echo " - ⚪ jwdeb_upgrade"
    echo " - 🔴 jwdeb_dist-upgrade"
    echo
    echo " -----------------------------  system maintenance"
    echo " - 🔴 jwdeb_autoremove"
    echo " - 🔴 jwdeb_autoclean"
    echo " - 🔴 jwdeb_clean"
    echo
    echo " -----------------------------  package analysis"
    echo " - 🟢 jwdeb_installed"
    echo " - 🟢 jwdeb_size"
    echo " - 🟢 jwdeb_orphans"
    echo " - 🟢 jwdeb_history"
    echo
    echo " -----------------------------  troubleshooting"
    echo " - 🟢 jwdeb_broken"
    echo " - ⚪ jwdeb_fix"
    echo " - 🟢 jwdeb_diag"
    echo
}


# ---------------------------------------------------------------------------------
# internal helpers
# ---------------------------------------------------------------------------------

# Column-align "Label: value" rows in grouped info/summary blocks. Optional 3rd
# arg overrides the column width (default 24) for blocks whose longest label
# differs (e.g. diag package-stats=27, size deps / cache "final" totals=29).
__jwdeb_kv__() {
    printf "%-${3:-24}s%s\n" "$1" "$2"
}


# ---------------------------------------------------------------------------------
# package search and information
# ---------------------------------------------------------------------------------

jwdeb_search() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdeb_search <search_term> [options]"
        echo "Examples:"
        echo "  jwdeb_search nginx"
        echo "  jwdeb_search python3 --installed"
        echo "  jwdeb_search editor --names-only"
        echo
        echo "Options:"
        echo "  --installed     Search only installed packages"
        echo "  --names-only    Search package names only"
        echo "  --full          Show full descriptions"
        return 1
    fi

    local SEARCH_TERM=$1
    shift
    local opt_installed="" opt_names="" opt_full="" opt
    for opt in "$@"; do
        case $opt in
            --installed)  opt_installed="yes" ;;
            --names-only) opt_names="yes" ;;
            --full)       opt_full="yes" ;;
        esac
    done
    
    echo "Searching for packages matching '$SEARCH_TERM'..."
    echo
    
    if [ -n "$opt_installed" ]; then
        echo "---[ Installed Packages ]---------------------------"
        if [ -n "$opt_names" ]; then
            dpkg -l | grep -i "$SEARCH_TERM" | awk '{printf "%-30s %s\n", $2, $3}'
        else
            apt list --installed 2>/dev/null | grep -i "$SEARCH_TERM"
        fi
    elif [ -n "$opt_names" ]; then
        echo "---[ Package Names ]--------------------------------"
        apt-cache pkgnames | grep -i "$SEARCH_TERM"
    elif [ -n "$opt_full" ]; then
        echo "---[ Detailed Search Results ]----------------------"
        apt-cache search "$SEARCH_TERM"
        echo
        echo "---[ Package Details ]------------------------------"
        apt-cache search "$SEARCH_TERM" | head -3 | while read -r pkg _; do
            echo "Package: $pkg"
            apt-cache show "$pkg" 2>/dev/null | grep -E "^(Version|Description|Size|Depends):" | head -4
            echo
        done
    else
        echo "---[ Search Results ]-------------------------------"
        apt-cache search "$SEARCH_TERM"
    fi
    echo
}


jwdeb_info() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdeb_info <package_name>"
        echo "Examples:"
        echo "  jwdeb_info nginx"
        echo "  jwdeb_info python3-pip"
        echo
        echo "Available packages (recently updated):"
        apt list --upgradable 2>/dev/null | head -5 | tail -n +2 | cut -d'/' -f1 | sed 's/^/- /'
        echo
        return 1
    fi

    local PACKAGE=$1
    
    echo "📦 Package Information: $PACKAGE"
    echo "=================================================="
    echo
    
    # Check if package is installed
    if dpkg -l "$PACKAGE" 2>/dev/null | grep -q "^ii"; then
        echo "---[ Installation Status ]-------------------------"
        echo "✅ Package is installed"
        local installed_version
        installed_version=$(dpkg -l "$PACKAGE" 2>/dev/null | grep "^ii" | awk '{print $3}')
        echo "Installed version: $installed_version"
        echo
        
        # Show installed package info
        echo "---[ Installed Package Details ]-------------------"
        dpkg -s "$PACKAGE" 2>/dev/null | grep -E "^(Package|Version|Architecture|Maintainer|Description|Installed-Size|Depends|Recommends):"
        echo
    else
        echo "---[ Installation Status ]-------------------------"
        echo "❌ Package is not installed"
        echo
    fi
    
    # Show available package info
    echo "---[ Available Package Details ]-------------------"
    if apt-cache show "$PACKAGE" >/dev/null 2>&1; then
        apt-cache show "$PACKAGE" 2>/dev/null | head -20 | grep -E "^(Package|Version|Architecture|Maintainer|Description|Size|Depends|Recommends|Suggests):"
    else
        echo "❌ Package not found in repositories"
    fi
    echo
    
    # Show reverse dependencies if installed
    if dpkg -l "$PACKAGE" 2>/dev/null | grep -q "^ii"; then
        echo "---[ Reverse Dependencies ]------------------------"
        local reverse_deps
        reverse_deps=$(apt-cache rdepends "$PACKAGE" 2>/dev/null | grep -v "Reverse Depends:" | head -10)
        if [ -n "$reverse_deps" ]; then
            printf '%s\n' "$reverse_deps" | sed 's/^/  /'
        else
            echo "  (no reverse dependencies found)"
        fi
        echo
    fi
}


jwdeb_depends() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdeb_depends <package_name> [--tree]"
        echo "Examples:"
        echo "  jwdeb_depends nginx"
        echo "  jwdeb_depends python3 --tree"
        echo
        echo "Available installed packages:"
        dpkg -l | grep "^ii" | awk '{print $2}' | head -10 | sed 's/^/- /'
        echo
        return 1
    fi

    local PACKAGE=$1
    local TREE_MODE=""
    
    if [ "$2" = "--tree" ]; then
        TREE_MODE="yes"
    fi
    
    echo "🔗 Dependencies for: $PACKAGE"
    echo "=================================================="
    echo
    
    if [ -n "$TREE_MODE" ]; then
        echo "---[ Dependency Tree ]------------------------------"
        if command -v apt-rdepends >/dev/null 2>&1; then
            apt-rdepends "$PACKAGE" 2>/dev/null
        else
            echo "⚠️  apt-rdepends not available. Install with: sudo apt install apt-rdepends"
            echo "Showing basic dependencies instead:"
            apt-cache depends "$PACKAGE" 2>/dev/null
        fi
    else
        echo "---[ Direct Dependencies ]--------------------------"
        apt-cache depends "$PACKAGE" 2>/dev/null | grep -E "^\s*(Depends|Recommends|Suggests):"
        echo
        
        echo "---[ Reverse Dependencies ]------------------------"
        apt-cache rdepends "$PACKAGE" 2>/dev/null
    fi
    echo
}


jwdeb_files() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdeb_files <package_name>"
        echo "Examples:"
        echo "  jwdeb_files nginx"
        echo "  jwdeb_files python3-pip"
        echo
        echo "Recently installed packages:"
        grep " install " /var/log/dpkg.log 2>/dev/null | tail -5 | awk '{print $4}' | sed 's/^/- /' || echo "- (log not accessible)"
        echo
        return 1
    fi

    local PACKAGE=$1
    
    echo "📁 Files installed by: $PACKAGE"
    echo "=================================================="
    echo
    
    # Check if package is installed
    if ! dpkg -l "$PACKAGE" 2>/dev/null | grep -q "^ii"; then
        echo "❌ Package '$PACKAGE' is not installed"
        echo
        return 1
    fi
    
    echo "---[ Configuration Files ]-------------------------"
    dpkg -L "$PACKAGE" 2>/dev/null | grep -E "^/etc/" | sed 's/^/  /' || echo "  (no configuration files)"
    echo
    
    echo "---[ Executables ]----------------------------------"
    dpkg -L "$PACKAGE" 2>/dev/null | grep -E "^/(usr/)?s?bin/" | sed 's/^/  /' || echo "  (no executables)"
    echo
    
    echo "---[ Documentation ]-------------------------------"
    dpkg -L "$PACKAGE" 2>/dev/null | grep -E "^/usr/share/(doc|man)/" | sed 's/^/  /' || echo "  (no documentation)"
    echo
    
    echo "---[ All Files ]-----------------------------------"
    dpkg -L "$PACKAGE" 2>/dev/null | sed 's/^/  /'
    
    local total_files
    total_files=$(dpkg -L "$PACKAGE" 2>/dev/null | wc -l)
    echo "  ... ($total_files total files)"
    echo
}


jwdeb_which() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdeb_which <file_path>"
        echo "Examples:"
        echo "  jwdeb_which /usr/bin/nginx"
        echo "  jwdeb_which /etc/nginx/nginx.conf"
        echo "  jwdeb_which nginx"
        echo
        return 1
    fi

    local FILE_PATH=$1
    
    echo "🔍 Finding package that owns: $FILE_PATH"
    echo "=================================================="
    echo
    
    # If it's just a command name, try to find the full path first
    if [[ "$FILE_PATH" != /* ]]; then
        local full_path
        full_path=$(which "$FILE_PATH" 2>/dev/null)
        if [ -n "$full_path" ]; then
            echo "Command '$FILE_PATH' found at: $full_path"
            FILE_PATH="$full_path"
        else
            echo "⚠️  Command '$FILE_PATH' not found in PATH"
            echo "Searching for files containing '$FILE_PATH'..."
            echo
        fi
    fi
    
    # Search for the file
    local owner_package
    owner_package=$(dpkg -S "$FILE_PATH" 2>/dev/null | cut -d: -f1)
    
    if [ -n "$owner_package" ]; then
        echo "---[ Package Owner ]-------------------------------"
        echo "✅ File owned by: $owner_package"
        echo
        
        # Show package info
        echo "---[ Package Information ]-------------------------"
        dpkg -s "$owner_package" 2>/dev/null | grep -E "^(Package|Version|Description):"
        echo
        
        # Show other files from same package in same directory
        local dir_path
        dir_path=$(dirname "$FILE_PATH")
        echo "---[ Other Files in $dir_path ]-------------------"
        dpkg -L "$owner_package" 2>/dev/null | grep "^$dir_path/" | head -5 | sed 's/^/  /'
    else
        echo "❌ No package owns this file"
        echo
        
        # Try apt-file if available
        if command -v apt-file >/dev/null 2>&1; then
            echo "---[ Searching with apt-file ]---------------------"
            apt-file search "$FILE_PATH" 2>/dev/null | head -10 | sed 's/^/  /' || echo "  (no results)"
        else
            echo "💡 Install apt-file for more comprehensive searching:"
            echo "   sudo apt install apt-file && sudo apt-file update"
        fi
    fi
    echo
}


jwdeb_policy() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwdeb_policy [package_name ...]"
        echo "Examples:"
        echo "  jwdeb_policy                 # Repository priorities (apt pinning)"
        echo "  jwdeb_policy nginx           # Installed/candidate versions for a package"
        echo "  jwdeb_policy nginx curl      # ... for several packages"
        return 0
    fi

    # No-args: overall repository priorities (read-only default).
    if [ $# -eq 0 ]; then
        echo "📊 APT Repository Priorities"
        echo "=================================================="
        echo
        apt-cache policy
        echo
        return 0
    fi

    local pkg out
    for pkg in "$@"; do
        echo "📊 Policy: $pkg"
        echo "=================================================="
        out=$(apt-cache policy "$pkg" 2>/dev/null)
        if [ -n "$out" ]; then
            printf '%s\n' "$out"
        else
            echo "❌ Package '$pkg' not found"
        fi
        echo
    done
}


# ---------------------------------------------------------------------------------
# package management
# ---------------------------------------------------------------------------------

jwdeb_install() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdeb_install <package_name> [package2] [package3] ..."
        echo "Examples:"
        echo "  jwdeb_install nginx"
        echo "  jwdeb_install python3-pip python3-venv"
        echo "  jwdeb_install ./package.deb"
        echo
        echo "Popular packages you might want to install:"
        echo "- curl wget git vim nano htop tree"
        echo "- python3-pip nodejs npm"
        echo "- nginx apache2 mysql-server postgresql"
        echo
        return 1
    fi

    echo "📦 Installing packages: $*"
    echo "=================================================="
    echo
    
    # Check if packages exist (for non-local .deb files)
    local missing_packages=()
    for package in "$@"; do
        if [[ "$package" != *.deb ]] && [[ "$package" != ./* ]] && [[ "$package" != /* ]]; then
            if ! apt-cache show "$package" >/dev/null 2>&1; then
                missing_packages+=("$package")
            fi
        fi
    done
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        echo "❌ The following packages were not found:"
        for pkg in "${missing_packages[@]}"; do
            echo "  - $pkg"
        done
        echo
        echo "💡 Try searching first: jwdeb_search <term>"
        return 1
    fi
    
    # Show what will be installed
    echo "---[ Installation Plan ]---------------------------"
    apt-get install -s "$@" 2>/dev/null | grep -E "^(Inst|Conf)" | head -10
    echo
    
    echo -n "Proceed with installation? [y/N] "
    read -r response
    
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        echo "Installing packages..."
        sudo apt-get update && sudo apt-get install -y "$@"
        
        echo
        echo "---[ Installation Summary ]------------------------"
        for package in "$@"; do
            if [[ "$package" != *.deb ]] && [[ "$package" != ./* ]] && [[ "$package" != /* ]]; then
                if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
                    local version=""
                    version=$(dpkg -l "$package" 2>/dev/null | grep "^ii" | awk '{print $3}')
                    echo "✅ $package ($version)"
                else
                    echo "❌ $package (installation failed)"
                fi
            fi
        done
    else
        echo "Installation cancelled."
    fi
    echo
}


jwdeb_remove() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdeb_remove <package_name> [package2] [package3] ..."
        echo "Examples:"
        echo "  jwdeb_remove nginx"
        echo "  jwdeb_remove python3-pip python3-venv"
        echo
        echo "Recently installed packages:"
        grep " install " /var/log/dpkg.log 2>/dev/null | tail -10 | awk '{print $4}' | sed 's/^/- /' || echo "- (log not accessible)"
        echo
        return 1
    fi

    echo "🗑️  Removing packages: $*"
    echo "=================================================="
    echo
    
    # Check which packages are actually installed
    local installed_packages=()
    local not_installed=()

    for package in "$@"; do
        if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
            installed_packages+=("$package")
        else
            not_installed+=("$package")
        fi
    done

    if [ ${#not_installed[@]} -gt 0 ]; then
        echo "⚠️  The following packages are not installed:"
        for pkg in "${not_installed[@]}"; do
            echo "  - $pkg"
        done
        echo
    fi

    if [ ${#installed_packages[@]} -eq 0 ]; then
        echo "❌ No installed packages to remove."
        return 1
    fi
    
    # Show what will be removed
    echo "---[ Removal Plan ]--------------------------------"
    apt-get remove -s "${installed_packages[@]}" 2>/dev/null | grep -E "^Remv" | head -10
    echo

    # Show reverse dependencies
    echo "---[ Packages That Depend On These ]---------------"
    local rdeps=""
    for package in "${installed_packages[@]}"; do
        rdeps=$(apt-cache rdepends "$package" 2>/dev/null | grep -v "Reverse Depends:" | head -3)
        if [ -n "$rdeps" ]; then
            echo "$package:"
            printf '%s\n' "$rdeps" | sed 's/^/  /'
        fi
    done
    echo
    
    echo "⚠️  This will remove packages but keep configuration files."
    echo "   Use 'jwdeb_purge' to remove configuration files too."
    echo
    echo -n "Proceed with removal? [y/N] "
    read -r response
    
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        echo "Removing packages..."
        sudo apt-get remove -y "${installed_packages[@]}"

        echo
        echo "---[ Removal Summary ]-----------------------------"
        for package in "${installed_packages[@]}"; do
            if dpkg -l "$package" 2>/dev/null | grep -q "^rc"; then
                echo "✅ $package (removed, config files remain)"
            elif ! dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
                echo "✅ $package (completely removed)"
            else
                echo "❌ $package (removal failed)"
            fi
        done
        
        echo
        echo "💡 Run 'jwdeb_autoremove' to clean up unused dependencies"
    else
        echo "Removal cancelled."
    fi
    echo
}


jwdeb_purge() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdeb_purge <package_name> [package2] [package3] ..."
        echo "Examples:"
        echo "  jwdeb_purge nginx"
        echo "  jwdeb_purge python3-pip python3-venv"
        echo
        echo "⚠️  WARNING: This completely removes packages AND their configuration files!"
        echo
        echo "Packages with remaining config files:"
        dpkg -l | grep "^rc" | awk '{print "- " $2}' | head -10
        echo
        return 1
    fi

    echo "🗑️  Purging packages (including config files): $*"
    echo "=================================================="
    echo
    
    # Check package status
    local can_purge=()
    local not_found=()

    for package in "$@"; do
        if dpkg -l "$package" 2>/dev/null | grep -qE "^(ii|rc)"; then
            can_purge+=("$package")
        else
            not_found+=("$package")
        fi
    done

    if [ ${#not_found[@]} -gt 0 ]; then
        echo "⚠️  The following packages are not installed or available:"
        for pkg in "${not_found[@]}"; do
            echo "  - $pkg"
        done
        echo
    fi

    if [ ${#can_purge[@]} -eq 0 ]; then
        echo "❌ No packages available for purging."
        return 1
    fi
    
    # Show what will be purged
    echo "---[ Purge Plan ]----------------------------------"
    local pkg_state=""
    for package in "${can_purge[@]}"; do
        pkg_state=$(dpkg -l "$package" 2>/dev/null | grep -E "^(ii|rc)" | awk '{print $1}')
        case $pkg_state in
            ii)
                echo "  $package (installed - will remove and purge)"
                ;;
            rc)
                echo "  $package (config files only - will purge)"
                ;;
        esac
    done
    echo
    
    # Show configuration files that will be removed
    echo "---[ Configuration Files To Be Removed ]-----------"
    local config_files=""
    for package in "${can_purge[@]}"; do
        config_files=$(dpkg -L "$package" 2>/dev/null | grep "^/etc/" | head -3)
        if [ -n "$config_files" ]; then
            echo "$package:"
            printf '%s\n' "$config_files" | sed 's/^/  /'
        fi
    done
    echo
    
    echo "⚠️  WARNING: This action cannot be undone!"
    echo "   All configuration files will be permanently deleted."
    echo
    echo -n "Proceed with purge? [y/N] "
    read -r response
    
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        echo "Purging packages..."
        sudo apt-get purge -y "${can_purge[@]}"

        echo
        echo "---[ Purge Summary ]-------------------------------"
        for package in "${can_purge[@]}"; do
            if ! dpkg -l "$package" 2>/dev/null | grep -qE "^(ii|rc)"; then
                echo "✅ $package (completely purged)"
            else
                echo "❌ $package (purge failed)"
            fi
        done
        
        echo
        echo "💡 Run 'jwdeb_autoremove' to clean up unused dependencies"
    else
        echo "Purge cancelled."
    fi
    echo
}


jwdeb_reinstall() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdeb_reinstall <package_name> [package2] ..."
        echo "Examples:"
        echo "  jwdeb_reinstall nginx        # Re-install nginx (repair its files)"
        echo "  jwdeb_reinstall python3 curl"
        echo
        echo "Re-downloads and reinstalls already-installed packages at the same"
        echo "version — useful to repair corrupted or deleted files."
        echo
        return 1
    fi

    echo "♻️  Reinstalling packages: $*"
    echo "=================================================="
    echo

    local not_installed=() pkg
    for pkg in "$@"; do
        if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            not_installed+=("$pkg")
        fi
    done

    if [ ${#not_installed[@]} -gt 0 ]; then
        echo "⚠️  Not installed (reinstall needs an installed package):"
        for pkg in "${not_installed[@]}"; do
            echo "  - $pkg"
        done
        echo
        echo "💡 Use 'jwdeb_install' to install them first."
        return 1
    fi

    echo -n "Proceed with reinstall? [y/N] "
    read -r response

    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        echo "Reinstalling..."
        sudo apt-get install --reinstall -y "$@"
        echo
        echo "✅ Reinstall complete"
    else
        echo "Reinstall cancelled."
    fi
    echo
}


jwdeb_download() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdeb_download <package_name> [package2] ..."
        echo "Examples:"
        echo "  jwdeb_download nginx         # Fetch nginx's .deb into the current dir"
        echo "  jwdeb_download nginx curl"
        echo
        echo "Downloads the .deb file(s) into \$PWD without installing — no sudo"
        echo "needed. Install a local file later with: jwdeb_install ./<file>.deb"
        echo
        return 1
    fi

    echo "⬇️  Downloading .deb package(s) into: $PWD"
    echo "=================================================="
    echo

    local missing=() pkg
    for pkg in "$@"; do
        if ! apt-cache show "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "❌ Not found in repositories:"
        for pkg in "${missing[@]}"; do
            echo "  - $pkg"
        done
        echo
        echo "💡 Try searching first: jwdeb_search <term>"
        return 1
    fi

    if apt-get download "$@"; then
        echo
        echo "✅ Done — .deb file(s) saved to $PWD"
        echo "💡 Install a local .deb with: jwdeb_install ./<file>.deb"
    else
        echo
        echo "❌ Download failed"
        return 1
    fi
    echo
}


jwdeb_hold() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwdeb_hold [package_name ...]"
        echo "Examples:"
        echo "  jwdeb_hold                   # List packages currently on hold"
        echo "  jwdeb_hold nginx             # Hold nginx at its current version"
        echo "  jwdeb_hold nginx curl        # Hold several packages"
        echo
        echo "A held package is kept at its current version (skipped by upgrades)."
        echo "Release a hold with jwdeb_unhold."
        return 0
    fi

    # No-args: list current holds (read-only default).
    if [ $# -eq 0 ]; then
        echo "🔒 Packages on hold"
        echo "=================================================="
        echo
        local held
        held=$(apt-mark showhold 2>/dev/null)
        if [ -n "$held" ]; then
            printf '%s\n' "$held" | sed 's/^/  🔒 /'
        else
            echo "  (no packages are held)"
        fi
        echo
        return 0
    fi

    echo "🔒 Holding packages: $*"
    echo "=================================================="
    echo

    local to_hold=() missing=() pkg
    for pkg in "$@"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            to_hold+=("$pkg")
        else
            missing+=("$pkg")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "⚠️  Not installed (cannot hold):"
        for pkg in "${missing[@]}"; do
            echo "  - $pkg"
        done
        echo
    fi

    if [ ${#to_hold[@]} -eq 0 ]; then
        echo "❌ No installed packages to hold."
        return 1
    fi

    sudo apt-mark hold "${to_hold[@]}"
    echo
    echo "---[ Now on hold ]---------------------------------"
    apt-mark showhold 2>/dev/null | sed 's/^/  🔒 /'
    echo
}


jwdeb_unhold() {
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwdeb_unhold <package_name ...>"
        echo "Examples:"
        echo "  jwdeb_unhold nginx           # Release the hold on nginx"
        echo "  jwdeb_unhold nginx curl      # Release several"
        echo
        echo "Currently held packages:"
        local held
        held=$(apt-mark showhold 2>/dev/null)
        if [ -n "$held" ]; then
            printf '%s\n' "$held" | sed 's/^/  🔒 /'
        else
            echo "  (none)"
        fi
        echo
        return 1
    fi

    echo "🔓 Releasing hold: $*"
    echo "=================================================="
    echo

    local held_now
    held_now=$(apt-mark showhold 2>/dev/null)
    local to_unhold=() not_held=() pkg
    for pkg in "$@"; do
        if printf '%s\n' "$held_now" | grep -qxF "$pkg"; then
            to_unhold+=("$pkg")
        else
            not_held+=("$pkg")
        fi
    done

    if [ ${#not_held[@]} -gt 0 ]; then
        echo "⚠️  Not currently held:"
        for pkg in "${not_held[@]}"; do
            echo "  - $pkg"
        done
        echo
    fi

    if [ ${#to_unhold[@]} -eq 0 ]; then
        echo "❌ No held packages to release."
        return 1
    fi

    sudo apt-mark unhold "${to_unhold[@]}"
    echo
    echo "---[ Still on hold ]-------------------------------"
    local still
    still=$(apt-mark showhold 2>/dev/null)
    if [ -n "$still" ]; then
        printf '%s\n' "$still" | sed 's/^/  🔒 /'
    else
        echo "  (none)"
    fi
    echo
}


# ---------------------------------------------------------------------------------
# system updates
# ---------------------------------------------------------------------------------

jwdeb_update() {
    echo "🔄 Updating package lists..."
    echo "=================================================="
    echo
    
    # Show current update status
    echo "---[ Current Status ]------------------------------"
    local last_update
    if [ -f /var/lib/apt/periodic/update-success-stamp ]; then
        last_update=$(stat -c %y /var/lib/apt/periodic/update-success-stamp 2>/dev/null | cut -d' ' -f1)
        echo "Last successful update: $last_update"
    else
        echo "Last update: Unknown"
    fi
    
    local upgradable_count
    upgradable_count=$(apt list --upgradable 2>/dev/null | wc -l)
    upgradable_count=$((upgradable_count - 1))  # Subtract header line
    echo "Packages with updates available: $upgradable_count"
    echo
    
    # Update package lists
    echo "---[ Updating Package Lists ]----------------------"
    sudo apt-get update
    
    # Show what's new
    echo
    echo "---[ Update Summary ]------------------------------"
    local new_upgradable_count
    new_upgradable_count=$(apt list --upgradable 2>/dev/null | wc -l)
    new_upgradable_count=$((new_upgradable_count - 1))
    
    echo "Packages with updates available: $new_upgradable_count"
    
    if [ "$new_upgradable_count" -gt 0 ]; then
        echo
        echo "---[ Available Updates (first 10) ]----------------"
        apt list --upgradable 2>/dev/null | head -11 | tail -n +2 | while read -r line; do
            package=$(echo "$line" | cut -d'/' -f1)
            version_info=$(echo "$line" | grep -o '\[.*\]' || echo "")
            echo "  📦 $package $version_info"
        done
        echo
        echo "💡 Run 'jwdeb_upgrade' to install available updates"
    else
        echo "✅ All packages are up to date!"
    fi
    echo
}


jwdeb_upgrade() {
    if [ "$1" = "--dist" ]; then
        jwdeb_dist-upgrade
        return
    fi
    
    echo "⬆️  Upgrading installed packages..."
    echo "=================================================="
    echo
    
    # Check for available updates
    local upgradable_count
    upgradable_count=$(apt list --upgradable 2>/dev/null | wc -l)
    upgradable_count=$((upgradable_count - 1))
    
    if [ "$upgradable_count" -eq 0 ]; then
        echo "✅ All packages are already up to date!"
        return 0
    fi
    
    echo "---[ Available Updates ]---------------------------"
    echo "Found $upgradable_count packages with updates available"
    echo
    
    # Show first 15 packages to be upgraded
    echo "Packages to be upgraded (first 15):"
    apt list --upgradable 2>/dev/null | head -16 | tail -n +2 | while read -r line; do
        package=$(echo "$line" | cut -d'/' -f1)
        version_info=$(echo "$line" | grep -o '\[.*\]' || echo "")
        echo "  📦 $package $version_info"
    done
    
    if [ "$upgradable_count" -gt 15 ]; then
        echo "  ... and $((upgradable_count - 15)) more packages"
    fi
    echo
    
    # Show upgrade simulation
    echo "---[ Upgrade Simulation ]---------------------------"
    apt-get upgrade -s 2>/dev/null | grep -cE "^(Inst|Conf)" | xargs echo "Operations to perform:"
    echo
    
    # Check for held packages
    local held_packages
    held_packages=$(apt-mark showhold 2>/dev/null)
    if [ -n "$held_packages" ]; then
        echo "---[ Held Packages (will not be upgraded) ]--------"
        printf '%s\n' "$held_packages" | sed 's/^/  🔒 /'
        echo
    fi
    
    echo -n "Proceed with upgrade? [y/N] "
    read -r response
    
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        echo "Upgrading packages..."
        sudo apt-get upgrade -y
        
        echo
        echo "---[ Upgrade Complete ]----------------------------"
        local remaining_updates
        remaining_updates=$(apt list --upgradable 2>/dev/null | wc -l)
        remaining_updates=$((remaining_updates - 1))
        
        if [ "$remaining_updates" -eq 0 ]; then
            echo "✅ All packages successfully upgraded!"
        else
            echo "⚠️  $remaining_updates packages still have updates available"
            echo "   (may require dist-upgrade or have held packages)"
        fi
        
        # Check if reboot is required
        if [ -f /var/run/reboot-required ]; then
            echo
            echo "🔄 System reboot is required to complete the upgrade"
            if [ -f /var/run/reboot-required.pkgs ]; then
                echo "Packages requiring reboot:"
                sed 's/^/  - /' /var/run/reboot-required.pkgs
            fi
        fi
    else
        echo "Upgrade cancelled."
    fi
    echo
}


jwdeb_dist-upgrade() {
    echo "🚀 Performing distribution upgrade..."
    echo "=================================================="
    echo
    
    echo "⚠️  WARNING: Distribution upgrade can:"
    echo "   - Install new packages"
    echo "   - Remove conflicting packages"
    echo "   - Change system behavior"
    echo "   - Require significant time and bandwidth"
    echo
    
    # Show what dist-upgrade would do
    echo "---[ Distribution Upgrade Simulation ]--------------"
    local simulation
    simulation=$(apt-get dist-upgrade -s 2>/dev/null)
    
    local install_count
    local upgrade_count
    local remove_count
    
    install_count=$(echo "$simulation" | grep -c "^Inst")
    upgrade_count=$(echo "$simulation" | grep -c "^Inst.*\[upgrade")
    remove_count=$(echo "$simulation" | grep -c "^Remv")
    
    echo "Packages to install: $install_count"
    echo "Packages to upgrade: $upgrade_count"
    echo "Packages to remove: $remove_count"
    echo
    
    if [ "$remove_count" -gt 0 ]; then
        echo "---[ Packages To Be Removed ]----------------------"
        echo "$simulation" | grep "^Remv" | head -10 | awk '{print "  🗑️  " $2}'
        if [ "$remove_count" -gt 10 ]; then
            echo "  ... and $((remove_count - 10)) more packages"
        fi
        echo
    fi
    
    if [ "$install_count" -gt 0 ]; then
        echo "---[ New Packages To Be Installed ]----------------"
        echo "$simulation" | grep "^Inst" | grep -v "\[upgrade" | head -10 | awk '{print "  📦 " $2}'
        if [ "$((install_count - upgrade_count))" -gt 10 ]; then
            echo "  ... and $((install_count - upgrade_count - 10)) more packages"
        fi
        echo
    fi
    
    echo "💡 This is more aggressive than 'jwdeb_upgrade' and may change system behavior"
    echo
    echo -n "Proceed with distribution upgrade? [y/N] "
    read -r response
    
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        echo "Performing distribution upgrade..."
        sudo apt-get dist-upgrade -y
        
        echo
        echo "---[ Distribution Upgrade Complete ]---------------"
        
        # Check final status
        local remaining_updates
        remaining_updates=$(apt list --upgradable 2>/dev/null | wc -l)
        remaining_updates=$((remaining_updates - 1))
        
        if [ "$remaining_updates" -eq 0 ]; then
            echo "✅ All packages successfully upgraded!"
        else
            echo "⚠️  $remaining_updates packages still have updates available"
        fi
        
        # Check if reboot is required
        if [ -f /var/run/reboot-required ]; then
            echo
            echo "🔄 System reboot is required to complete the upgrade"
            if [ -f /var/run/reboot-required.pkgs ]; then
                echo "Packages requiring reboot:"
                sed 's/^/  - /' /var/run/reboot-required.pkgs
            fi
        fi
        
        echo
        echo "💡 Consider running 'jwdeb_autoremove' to clean up unused packages"
    else
        echo "Distribution upgrade cancelled."
    fi
    echo
}


# ---------------------------------------------------------------------------------
# system maintenance
# ---------------------------------------------------------------------------------

jwdeb_autoremove() {
    echo "🧹 Removing automatically installed unused packages..."
    echo "=================================================="
    echo
    
    # Check for packages that can be autoremoved
    local autoremove_list
    autoremove_list=$(apt-get autoremove -s 2>/dev/null | grep "^Remv" | awk '{print $2}')
    
    if [ -z "$autoremove_list" ]; then
        echo "✅ No unused packages found - system is clean!"
        return 0
    fi
    
    local package_count
    package_count=$(echo "$autoremove_list" | wc -l)
    
    echo "---[ Packages To Be Removed ]----------------------"
    echo "Found $package_count unused packages:"
    echo "$autoremove_list" | head -15 | sed 's/^/  🗑️  /'
    
    if [ "$package_count" -gt 15 ]; then
        echo "  ... and $((package_count - 15)) more packages"
    fi
    echo
    
    # Calculate space to be freed
    local size_info
    size_info=$(apt-get autoremove -s 2>/dev/null | grep "freed" | tail -1)
    if [ -n "$size_info" ]; then
        echo "Disk space to be freed: $(echo "$size_info" | grep -o '[0-9,.]* [kMG]B')"
        echo
    fi
    
    echo "💡 These packages were automatically installed as dependencies"
    echo "   and are no longer needed by any installed packages."
    echo
    echo -n "Proceed with autoremove? [y/N] "
    read -r response
    
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        echo "Removing unused packages..."
        sudo apt-get autoremove -y
        
        echo
        echo "---[ Autoremove Complete ]-------------------------"
        
        # Check if there are still packages to remove
        local remaining_autoremove
        remaining_autoremove=$(apt-get autoremove -s 2>/dev/null | grep -c "^Remv")
        
        if [ "$remaining_autoremove" -eq 0 ]; then
            echo "✅ All unused packages removed successfully!"
        else
            echo "⚠️  $remaining_autoremove packages still marked for autoremoval"
        fi
        
        echo
        echo "💡 Run 'jwdeb_autoclean' to clean package cache"
    else
        echo "Autoremove cancelled."
    fi
    echo
}


jwdeb_autoclean() {
    echo "🧹 Cleaning package cache..."
    echo "=================================================="
    echo
    
    # Show current cache status
    echo "---[ Current Cache Status ]------------------------"
    local cache_dir="/var/cache/apt/archives"
    
    if [ -d "$cache_dir" ]; then
        local total_files
        local total_size
        local partial_files
        
        total_files=$(find "$cache_dir" -name "*.deb" | wc -l)
        total_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
        partial_files=$(find "$cache_dir" -name "*.deb.partial" | wc -l)
        
        __jwdeb_kv__ "Total cached packages:" "$total_files"
        __jwdeb_kv__ "Cache directory size:" "$total_size"
        if [ "$partial_files" -gt 0 ]; then
            __jwdeb_kv__ "Partial downloads:" "$partial_files"
        fi
    else
        echo "Cache directory not found"
    fi
    echo
    
    # Show what autoclean will do
    echo "---[ Autoclean Simulation ]------------------------"
    local autoclean_simulation
    autoclean_simulation=$(apt-get autoclean -s 2>/dev/null)
    
    if echo "$autoclean_simulation" | grep -q "Del"; then
        local files_to_remove
        files_to_remove=$(echo "$autoclean_simulation" | grep -c "^Del")
        echo "Obsolete package files to remove: $files_to_remove"
        
        echo "Files to be removed (first 10):"
        echo "$autoclean_simulation" | grep "^Del" | head -10 | awk '{print "  🗑️  " $2}' | sed 's/_[^_]*\.deb//'
        
        if [ "$files_to_remove" -gt 10 ]; then
            echo "  ... and $((files_to_remove - 10)) more files"
        fi
    else
        echo "✅ No obsolete package files found"
    fi
    echo
    
    echo "💡 Autoclean removes package files that can no longer be downloaded"
    echo "   (keeps current versions and dependencies)"
    echo
    echo -n "Proceed with autoclean? [y/N] "
    read -r response
    
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        echo "Cleaning package cache..."
        sudo apt-get autoclean
        
        echo
        echo "---[ Autoclean Complete ]--------------------------"
        
        # Show final cache status
        if [ -d "$cache_dir" ]; then
            local final_files
            local final_size
            
            final_files=$(find "$cache_dir" -name "*.deb" | wc -l)
            final_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
            
            __jwdeb_kv__ "Remaining cached packages:" "$final_files" 29
            __jwdeb_kv__ "Final cache directory size:" "$final_size" 29
        fi
        
        echo
        echo "💡 Use 'jwdeb_clean' for more aggressive cache cleaning"
    else
        echo "Autoclean cancelled."
    fi
    echo
}


jwdeb_clean() {
    echo "🧹 Cleaning ALL package cache files..."
    echo "=================================================="
    echo
    
    echo "⚠️  WARNING: This will remove ALL cached package files!"
    echo "   - Downloaded .deb files will be deleted"
    echo "   - Future installations will need to re-download packages"
    echo "   - This frees maximum disk space but increases bandwidth usage"
    echo
    
    # Show current cache status
    echo "---[ Current Cache Status ]------------------------"
    local cache_dir="/var/cache/apt/archives"
    
    if [ -d "$cache_dir" ]; then
        local total_files
        local total_size
        
        total_files=$(find "$cache_dir" -name "*.deb" | wc -l)
        total_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
        
        __jwdeb_kv__ "Total cached packages:" "$total_files"
        __jwdeb_kv__ "Cache directory size:" "$total_size"
        
        if [ "$total_files" -eq 0 ]; then
            echo "✅ Cache is already empty!"
            return 0
        fi
        
        echo
        echo "Recent packages in cache (last 10):"
        find "$cache_dir" -name "*.deb" -printf "%T@ %f\n" 2>/dev/null | sort -n | tail -10 | cut -d' ' -f2- | sed 's/^/  📦 /' | sed 's/_[^_]*\.deb//'
    else
        echo "Cache directory not found"
        return 1
    fi
    echo
    
    echo -n "Proceed with complete cache cleaning? [y/N] "
    read -r response
    
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        echo "Cleaning all package cache files..."
        sudo apt-get clean
        
        echo
        echo "---[ Clean Complete ]------------------------------"
        
        # Show final status
        if [ -d "$cache_dir" ]; then
            local final_files
            local final_size
            
            final_files=$(find "$cache_dir" -name "*.deb" | wc -l)
            final_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
            
            __jwdeb_kv__ "Remaining cached packages:" "$final_files" 29
            __jwdeb_kv__ "Final cache directory size:" "$final_size" 29
            
            if [ "$final_files" -eq 0 ]; then
                echo "✅ Package cache completely cleaned!"
            fi
        fi
    else
        echo "Clean cancelled."
    fi
    echo
}


# ---------------------------------------------------------------------------------
# package analysis
# ---------------------------------------------------------------------------------

jwdeb_installed() {
    local FILTER=""
    local SORT_MODE=""
    local MANUAL_ONLY=""

    # No-args runs the default (list all installed packages); usage lives under
    # -h/--help (CONVENTIONS.md → Parameter Handling).
    for arg in "$@"; do
        case $arg in
            -h|--help)
                echo "Usage: jwdeb_installed [filter] [--size|--date|--manual]"
                echo "Examples:"
                echo "  jwdeb_installed                    # List all installed packages"
                echo "  jwdeb_installed python             # Filter packages containing 'python'"
                echo "  jwdeb_installed --size             # Sort by size"
                echo "  jwdeb_installed --date             # Sort by installation date"
                echo "  jwdeb_installed --manual           # Show manually installed packages only"
                return 0
                ;;
            --size)
                SORT_MODE="size"
                ;;
            --date)
                SORT_MODE="date"
                ;;
            --manual)
                MANUAL_ONLY="yes"
                ;;
            --*)
                echo "Unknown option: $arg"
                return 1
                ;;
            *)
                FILTER="$arg"
                ;;
        esac
    done
    
    echo "📦 Installed Packages"
    if [ -n "$FILTER" ]; then
        echo "Filter: $FILTER"
    fi
    if [ -n "$SORT_MODE" ]; then
        echo "Sort: $SORT_MODE"
    fi
    if [ -n "$MANUAL_ONLY" ]; then
        echo "Mode: manually installed only"
    fi
    echo "=================================================="
    echo
    
    if [ -n "$MANUAL_ONLY" ]; then
        echo "---[ Manually Installed Packages ]-----------------"
        local manual_packages
        manual_packages=$(apt-mark showmanual 2>/dev/null)
        
        if [ -n "$FILTER" ]; then
            manual_packages=$(echo "$manual_packages" | grep -i "$FILTER")
        fi
        
        if [ -n "$manual_packages" ]; then
            local count
            count=$(echo "$manual_packages" | wc -l)
            echo "Found $count manually installed packages:"
            echo
            
            echo "$manual_packages" | while read -r package; do
                if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
                    local version="" description=""
                    version=$(dpkg -l "$package" 2>/dev/null | grep "^ii" | awk '{print $3}')
                    description=$(dpkg -s "$package" 2>/dev/null | grep "^Description:" | cut -d' ' -f2- | head -1)
                    printf "  %-25s %-15s %s\n" "$package" "$version" "$description"
                fi
            done
        else
            echo "No manually installed packages found matching filter."
        fi
    elif [ "$SORT_MODE" = "size" ]; then
        echo "---[ Packages Sorted by Size ]---------------------"
        local package_list
        if [ -n "$FILTER" ]; then
            package_list=$(dpkg -l | grep "^ii" | grep -i "$FILTER" | awk '{print $2}')
        else
            package_list=$(dpkg -l | grep "^ii" | awk '{print $2}')
        fi
        
        echo "Package                   Size      Description"
        echo "----------------------------------------"
        
        echo "$package_list" | while read -r package; do
            local size="" description=""
            size=$(dpkg -s "$package" 2>/dev/null | grep "^Installed-Size:" | awk '{print $2}')
            description=$(dpkg -s "$package" 2>/dev/null | grep "^Description:" | cut -d' ' -f2- | head -1)
            
            if [ -n "$size" ]; then
                # Convert KB to human readable
                if [ "$size" -gt 1024 ]; then
                    size="$((size / 1024))MB"
                else
                    size="${size}KB"
                fi
                printf "%s|%-25s %-9s %s\n" "$size" "$package" "$size" "$description"
            fi
        done | sort -rn | cut -d'|' -f2-
        
    elif [ "$SORT_MODE" = "date" ]; then
        echo "---[ Packages Sorted by Installation Date ]--------"
        if command -v grep >/dev/null 2>&1 && [ -r /var/log/dpkg.log ]; then
            echo "Installations (oldest first):"
            echo
            
            local recent_installs
            if [ -n "$FILTER" ]; then
                recent_installs=$(grep " install " /var/log/dpkg.log 2>/dev/null | grep -i "$FILTER")
            else
                recent_installs=$(grep " install " /var/log/dpkg.log 2>/dev/null)
            fi
            
            echo "$recent_installs" | while read -r line; do
                local date_time="" package=""
                date_time=$(echo "$line" | awk '{print $1, $2}')
                package=$(echo "$line" | awk '{print $4}')
                printf "  %-20s %s\n" "$date_time" "$package"
            done
        else
            echo "⚠️  Installation date information not available"
            echo "   (requires access to /var/log/dpkg.log)"
        fi
        
    else
        echo "---[ Installed Packages ]---------------------------"
        local package_list
        if [ -n "$FILTER" ]; then
            package_list=$(dpkg -l | grep "^ii" | grep -i "$FILTER")
        else
            package_list=$(dpkg -l | grep "^ii")
        fi
        
        local count
        count=$(printf '%s\n' "$package_list" | grep -c .)
        echo "Found $count installed packages:"
        echo
        
        printf "%-29s %-22s %-8s %s\n" "Package" "Version" "Arch" "Description"
        echo "---------------------------------------------------------------------------"
        echo "$package_list" | awk '{
            printf "%-29s %-22s %-8s ", $2, $3, $4
            for(i=5; i<=NF; i++) printf "%s ", $i
            printf "\n"
        }'
    fi
    echo
}


jwdeb_size() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdeb_size <package_name> | --top [N]"
        echo "Examples:"
        echo "  jwdeb_size nginx              # Show size of a specific package"
        echo "  jwdeb_size --top              # Show the 10 largest installed packages"
        echo "  jwdeb_size --top 20           # Show the top 20 largest packages"
        echo
        echo "Note: --top scans every installed package (dpkg -s) and can take a"
        echo "while on a large system."
        echo
        return 1
    fi

    if [ "$1" = "--top" ]; then
        local TOP_COUNT=${2:-10}
        echo "📊 Top $TOP_COUNT Largest Packages"
        echo "=================================================="
        echo
        
        echo "Package                   Size      Description"
        echo "--------------------------------------------------------"
        
        dpkg -l | grep "^ii" | awk '{print $2}' | while read -r package; do
            local size="" description=""
            size=$(dpkg -s "$package" 2>/dev/null | grep "^Installed-Size:" | awk '{print $2}')
            description=$(dpkg -s "$package" 2>/dev/null | grep "^Description:" | cut -d' ' -f2- | head -1)
            
            if [ -n "$size" ] && [ "$size" -gt 0 ]; then
                printf "%08d|%-25s %s %s\n" "$size" "$package" "$size" "$description"
            fi
        done | sort -rn | head -"$TOP_COUNT" | while IFS='|' read -r _ package_info; do
            echo "$package_info" | awk '{
                size = $2
                if (size > 1024*1024) {
                    size_str = sprintf("%.1fGB", size/1024/1024)
                } else if (size > 1024) {
                    size_str = sprintf("%.1fMB", size/1024)
                } else {
                    size_str = size "KB"
                }
                printf "%-25s %-9s", $1, size_str
                for(i=3; i<=NF; i++) printf "%s ", $i
                printf "\n"
            }'
        done
        
    else
        local PACKAGE=$1
        echo "📊 Package Size Information: $PACKAGE"
        echo "=================================================="
        echo
        
        # Check if package is installed
        if ! dpkg -l "$PACKAGE" 2>/dev/null | grep -q "^ii"; then
            echo "❌ Package '$PACKAGE' is not installed"
            echo
            return 1
        fi
        
        echo "---[ Size Information ]-----------------------------"
        local installed_size
        local download_size
        
        installed_size=$(dpkg -s "$PACKAGE" 2>/dev/null | grep "^Installed-Size:" | awk '{print $2}')
        
        if [ -n "$installed_size" ]; then
            echo -n "Installed size: "
            if [ "$installed_size" -gt 1048576 ]; then
                echo "$(echo "scale=1; $installed_size / 1048576" | bc 2>/dev/null || echo "$((installed_size / 1048576))")GB ($installed_size KB)"
            elif [ "$installed_size" -gt 1024 ]; then
                echo "$(echo "scale=1; $installed_size / 1024" | bc 2>/dev/null || echo "$((installed_size / 1024))")MB ($installed_size KB)"
            else
                echo "${installed_size}KB"
            fi
        fi
        
        # Try to get download size from apt-cache
        download_size=$(apt-cache show "$PACKAGE" 2>/dev/null | grep "^Size:" | awk '{print $2}' | head -1)
        if [ -n "$download_size" ]; then
            echo -n "Download size: "
            if [ "$download_size" -gt 1048576 ]; then
                echo "$(echo "scale=1; $download_size / 1048576" | bc 2>/dev/null || echo "$((download_size / 1048576))")MB"
            elif [ "$download_size" -gt 1024 ]; then
                echo "$(echo "scale=1; $download_size / 1024" | bc 2>/dev/null || echo "$((download_size / 1024))")KB"
            else
                echo "${download_size}B"
            fi
        fi
        
        echo
        echo "---[ File Count ]-----------------------------------"
        local file_count
        file_count=$(dpkg -L "$PACKAGE" 2>/dev/null | wc -l)
        echo "Total files: $file_count"
        
        # Break down by file type
        echo
        echo "File breakdown:"
        local config_files
        local executables
        local docs
        local libs
        
        config_files=$(dpkg -L "$PACKAGE" 2>/dev/null | grep -c "^/etc/")
        executables=$(dpkg -L "$PACKAGE" 2>/dev/null | grep -cE "^/(usr/)?s?bin/")
        docs=$(dpkg -L "$PACKAGE" 2>/dev/null | grep -c "^/usr/share/doc/")
        libs=$(dpkg -L "$PACKAGE" 2>/dev/null | grep -c "\.so")
        
        __jwdeb_kv__ "  Configuration files:" "$config_files"
        __jwdeb_kv__ "  Executables:" "$executables"
        __jwdeb_kv__ "  Documentation:" "$docs"
        __jwdeb_kv__ "  Libraries:" "$libs"
        
        echo
        echo "---[ Dependencies Impact ]-------------------------"
        local dep_count
        dep_count=$(apt-cache depends "$PACKAGE" 2>/dev/null | grep -c "Depends:")
        __jwdeb_kv__ "Direct dependencies:" "$dep_count" 29

        local rdep_count
        rdep_count=$(apt-cache rdepends "$PACKAGE" 2>/dev/null | grep -cv "Reverse Depends:")
        __jwdeb_kv__ "Packages depending on this:" "$rdep_count" 29
    fi
    echo
}


jwdeb_orphans() {
    echo "🔍 Finding orphaned packages..."
    echo "=================================================="
    echo
    
    # Check if deborphan is available
    if ! command -v deborphan >/dev/null 2>&1; then
        echo "⚠️  deborphan not installed. Using alternative method..."
        echo
        echo "---[ Packages Marked for Autoremoval ]-------------"
        local autoremove_list
        autoremove_list=$(apt-get autoremove -s 2>/dev/null | grep "^Remv" | awk '{print $2}')
        
        if [ -n "$autoremove_list" ]; then
            local count
            count=$(echo "$autoremove_list" | wc -l)
            echo "Found $count packages that can be autoremoved:"
            printf '%s\n' "$autoremove_list" | sed 's/^/  🗑️  /'
            echo
            echo "💡 These packages were installed as dependencies and are no longer needed"
            echo "   Run 'jwdeb_autoremove' to remove them"
        else
            echo "✅ No packages marked for autoremoval found"
        fi
        
        echo
        echo "💡 Install deborphan for more comprehensive orphan detection:"
        echo "   sudo apt install deborphan"
        return 0
    fi
    
    echo "---[ Library Orphans ]------------------------------"
    local lib_orphans
    lib_orphans=$(deborphan 2>/dev/null)
    
    if [ -n "$lib_orphans" ]; then
        local lib_count
        lib_count=$(echo "$lib_orphans" | wc -l)
        echo "Found $lib_count orphaned library packages:"
        printf '%s\n' "$lib_orphans" | sed 's/^/  📚 /'
    else
        echo "✅ No orphaned library packages found"
    fi
    
    echo
    echo "---[ All Orphans ]----------------------------------"
    local all_orphans
    all_orphans=$(deborphan -a 2>/dev/null)
    
    if [ -n "$all_orphans" ]; then
        local all_count
        all_count=$(echo "$all_orphans" | wc -l)
        echo "Found $all_count total orphaned packages:"
        printf '%s\n' "$all_orphans" | sed 's/^/  🗑️  /'
    else
        echo "✅ No orphaned packages found"
    fi
    
    echo
    echo "---[ Package Categories ]---------------------------"
    echo "Orphans by category:"
    
    # Check different categories
    local cat_orphans="" cat_count=""
    for category in libs oldlibs devel doc; do
        cat_orphans=$(deborphan --section="$category" 2>/dev/null)
        if [ -n "$cat_orphans" ]; then
            cat_count=$(echo "$cat_orphans" | wc -l)
            echo "  $category: $cat_count packages"
        fi
    done
    
    echo
    echo "💡 Orphaned packages are installed but not required by any other package"
    echo "   Review carefully before removing - some may be manually installed"
    echo
    echo "Commands to clean up:"
    echo "  deborphan | xargs sudo apt-get remove --purge    # Remove library orphans"
    echo "  deborphan -a | xargs sudo apt-get remove --purge # Remove all orphans"
    echo
}


jwdeb_history() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: jwdeb_history [count] [--installs|--removes]"
        echo "Examples:"
        echo "  jwdeb_history                # Recent package operations (default 20)"
        echo "  jwdeb_history 50             # Last 50 operations"
        echo "  jwdeb_history --installs     # Recent installs only"
        echo "  jwdeb_history --removes      # Recent removals/purges only"
        return 0
    fi

    local count=20 actions="install|upgrade|remove|purge" label="operations"
    local arg
    for arg in "$@"; do
        case $arg in
            --installs) actions="install";      label="installs" ;;
            --removes)  actions="remove|purge"; label="removals" ;;
            --*)        echo "Unknown option: $arg"; return 1 ;;
            *[!0-9]*)   echo "Invalid count: $arg"; return 1 ;;
            *)          count="$arg" ;;
        esac
    done

    echo "🕓 Package History"
    echo "=================================================="
    echo

    if [ ! -r /var/log/dpkg.log ]; then
        echo "⚠️  /var/log/dpkg.log is not readable — cannot show history"
        echo
        return 1
    fi

    echo "---[ Last $count $label ]--------------------------"
    local rows
    rows=$(grep -E "^[0-9-]+ [0-9:]+ ($actions) " /var/log/dpkg.log 2>/dev/null | tail -n "$count")
    if [ -n "$rows" ]; then
        printf '%s\n' "$rows" | awk '{printf "  %s %s  %-8s %s\n", $1, $2, $3, $4}'
    else
        echo "  (no matching operations found)"
    fi
    echo
}


# ---------------------------------------------------------------------------------
# troubleshooting
# ---------------------------------------------------------------------------------

jwdeb_broken() {
    echo "🔧 Checking for broken packages..."
    echo "=================================================="
    echo
    
    echo "---[ Package Database Status ]---------------------"
    
    # Check dpkg status
    echo -n "dpkg database: "
    if dpkg --audit >/dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ Issues found"
        echo
        echo "dpkg audit results:"
        dpkg --audit | sed 's/^/  /'
        echo
    fi
    
    # Check for broken packages
    echo "---[ Broken Package Check ]------------------------"
    local broken_packages
    broken_packages=$(apt-get check 2>&1 | grep -E "^E:|^W:" || true)
    
    if [ -z "$broken_packages" ]; then
        echo "✅ No broken packages found"
    else
        echo "❌ Issues detected:"
        printf '%s\n' "$broken_packages" | sed 's/^/  /'
        echo
    fi
    
    # Check for packages in inconsistent state
    echo "---[ Package State Check ]-------------------------"
    local inconsistent_packages
    inconsistent_packages=$(dpkg -l | grep -E "^[^i]" | grep -v "^Desired" | grep -v "^|" | grep -v "^+++" || true)
    
    if [ -z "$inconsistent_packages" ]; then
        echo "✅ All packages in consistent state"
    else
        echo "⚠️  Packages in inconsistent state:"
        printf '%s\n' "$inconsistent_packages" | sed 's/^/  /' | head -10
        echo
    fi
    
    # Check for held broken packages
    echo "---[ Held Packages ]-------------------------------"
    local held_packages
    held_packages=$(apt-mark showhold 2>/dev/null)
    
    if [ -z "$held_packages" ]; then
        echo "✅ No held packages"
    else
        echo "🔒 Held packages (won't be upgraded):"
        printf '%s\n' "$held_packages" | sed 's/^/  /'
        echo
    fi
    
    # Check for unmet dependencies
    echo "---[ Dependency Check ]----------------------------"
    local unmet_deps
    unmet_deps=$(apt-get -s install 2>&1 | grep -E "^E:|unmet dependencies" || true)
    
    if [ -z "$unmet_deps" ]; then
        echo "✅ No unmet dependencies"
    else
        echo "❌ Unmet dependencies found:"
        printf '%s\n' "$unmet_deps" | sed 's/^/  /'
        echo
    fi
    
    # Check for packages that need configuration
    echo "---[ Configuration Status ]------------------------"
    local unconfigured
    unconfigured=$(dpkg -l | grep "^iU\|^iF" || true)
    
    if [ -z "$unconfigured" ]; then
        echo "✅ All packages properly configured"
    else
        echo "⚠️  Packages needing configuration:"
        printf '%s\n' "$unconfigured" | sed 's/^/  /'
        echo
    fi
    
    echo "---[ Recommended Actions ]-------------------------"
    if [ -n "$broken_packages" ] || [ -n "$unmet_deps" ] || [ -n "$unconfigured" ]; then
        echo "Try these commands to fix issues:"
        echo "  sudo apt-get update                    # Update package lists"
        echo "  sudo apt-get -f install                # Fix broken dependencies"
        echo "  sudo dpkg --configure -a               # Configure pending packages"
        echo "  jwdeb_fix                               # Run automated fix"
    else
        echo "✅ System appears to be in good condition"
    fi
    echo
}


jwdeb_fix() {
    echo "🔧 Attempting to fix package system issues..."
    echo "=================================================="
    echo
    
    echo "This will attempt to:"
    echo "  1. Update package lists"
    echo "  2. Fix broken dependencies"
    echo "  3. Configure pending packages"
    echo "  4. Clean package cache if needed"
    echo
    
    echo -n "Proceed with automated fix? [y/N] "
    read -r response
    
    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        echo "Fix cancelled."
        return 1
    fi
    
    echo
    echo "---[ Step 1: Updating Package Lists ]-------------"
    if sudo apt-get update; then
        echo "✅ Package lists updated successfully"
    else
        echo "❌ Failed to update package lists"
        echo "⚠️  Continuing with remaining steps..."
    fi
    
    echo
    echo "---[ Step 2: Configuring Pending Packages ]-------"
    if sudo dpkg --configure -a; then
        echo "✅ Package configuration completed"
    else
        echo "❌ Some packages failed to configure"
        echo "⚠️  Continuing with remaining steps..."
    fi
    
    echo
    echo "---[ Step 3: Fixing Broken Dependencies ]----------"
    if sudo apt-get -f install; then
        echo "✅ Dependencies fixed successfully"
    else
        echo "❌ Failed to fix some dependencies"
        echo "⚠️  Manual intervention may be required"
    fi
    
    echo
    echo "---[ Step 4: Checking Final Status ]---------------"
    local final_check
    final_check=$(apt-get check 2>&1 | grep -E "^E:|^W:" || true)
    
    if [ -z "$final_check" ]; then
        echo "✅ Package system appears to be fixed!"
    else
        echo "⚠️  Some issues remain:"
        printf '%s\n' "$final_check" | sed 's/^/  /'
        echo
        echo "Manual steps that might help:"
        echo "  sudo apt-get autoremove              # Remove unused packages"
        echo "  sudo apt-get autoclean               # Clean package cache"
        echo "  sudo apt-get dist-upgrade            # Upgrade with dependency resolution"
    fi
    
    echo
    echo "---[ Cleanup Recommendations ]---------------------"
    local autoremove_count
    autoremove_count=$(apt-get autoremove -s 2>/dev/null | grep -c "^Remv")
    
    if [ "$autoremove_count" -gt 0 ]; then
        echo "💡 $autoremove_count packages can be autoremoved"
        echo "   Run 'jwdeb_autoremove' to clean them up"
    fi
    
    local cache_size
    cache_size=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)
    echo "💡 Package cache size: $cache_size"
    echo "   Run 'jwdeb_autoclean' or 'jwdeb_clean' to free space"
    echo
}


jwdeb_diag() {
    echo "🔍 System Package Diagnostics"
    echo "=================================================="
    echo
    
    echo "---[ System Information ]---------------------------"
    echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    echo "Architecture: $(dpkg --print-architecture)"
    echo "Kernel: $(uname -r)"
    echo "Date: $(date)"
    echo
    
    echo "---[ Package Statistics ]---------------------------"
    local total_packages
    local installed_packages
    local upgradable_packages
    local autoremovable_packages
    
    total_packages=$(apt-cache pkgnames | wc -l)
    installed_packages=$(dpkg -l | grep -c "^ii")
    upgradable_packages=$(apt list --upgradable 2>/dev/null | wc -l)
    upgradable_packages=$((upgradable_packages - 1))  # Subtract header
    autoremovable_packages=$(apt-get autoremove -s 2>/dev/null | grep -c "^Remv")
    
    __jwdeb_kv__ "Total available packages:" "$total_packages" 27
    __jwdeb_kv__ "Installed packages:" "$installed_packages" 27
    __jwdeb_kv__ "Upgradable packages:" "$upgradable_packages" 27
    __jwdeb_kv__ "Autoremovable packages:" "$autoremovable_packages" 27
    echo
    
    echo "---[ Repository Status ]----------------------------"
    echo "Active repositories:"
    echo "  Count: $(awk '/^deb /{n++} END{print n+0}' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null)"
    
    echo "Last update:"
    if [ -f /var/lib/apt/periodic/update-success-stamp ]; then
        stat -c "  %y" /var/lib/apt/periodic/update-success-stamp
    else
        echo "  Unknown"
    fi
    echo
    
    echo "---[ Disk Usage ]-----------------------------------"
    echo "Package cache:"
    du -sh /var/cache/apt/archives 2>/dev/null | awk '{print "  " $1}' || echo "  Unknown"
    
    echo "Package database:"
    du -sh /var/lib/dpkg 2>/dev/null | awk '{print "  " $1}' || echo "  Unknown"
    
    echo "Available disk space:"
    df -h / | tail -1 | awk '{print "  " $4 " available (" $5 " used)"}'
    echo
    
    echo "---[ Recent Activity ]------------------------------"
    if [ -r /var/log/dpkg.log ]; then
        echo "Recent package operations (last 5):"
        tail -5 /var/log/dpkg.log | while read -r line; do
            local date_time="" operation="" package=""
            date_time=$(echo "$line" | awk '{print $1, $2}')
            operation=$(echo "$line" | awk '{print $3}')
            package=$(echo "$line" | awk '{print $4}')
            printf "  %-20s %-10s %s\n" "$date_time" "$operation" "$package"
        done
    else
        echo "  (log not accessible)"
    fi
    echo
    
    echo "---[ System Health ]--------------------------------"
    
    # Check for broken packages
    local broken_check
    broken_check=$(apt-get check 2>&1 | grep -E "^E:|^W:" || true)
    echo -n "Package integrity: "
    if [ -z "$broken_check" ]; then
        echo "✅ OK"
    else
        echo "❌ Issues detected"
    fi
    
    # Check dpkg database
    echo -n "dpkg database: "
    if dpkg --audit >/dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ Issues found"
    fi
    
    # Check for security updates
    if command -v unattended-upgrade >/dev/null 2>&1; then
        echo -n "Automatic updates: "
        if systemctl is-enabled unattended-upgrades >/dev/null 2>&1; then
            echo "✅ Enabled"
        else
            echo "⚠️  Disabled"
        fi
    fi
    
    # Check for reboot requirement
    echo -n "Reboot required: "
    if [ -f /var/run/reboot-required ]; then
        echo "⚠️  Yes"
        if [ -f /var/run/reboot-required.pkgs ]; then
            echo "  Packages requiring reboot:"
            sed 's/^/    /' /var/run/reboot-required.pkgs
        fi
    else
        echo "✅ No"
    fi
    
    echo
    echo "---[ Recommendations ]------------------------------"
    
    if [ "$upgradable_packages" -gt 0 ]; then
        echo "💡 $upgradable_packages packages can be upgraded - run 'jwdeb_upgrade'"
    fi
    
    if [ "$autoremovable_packages" -gt 0 ]; then
        echo "💡 $autoremovable_packages packages can be autoremoved - run 'jwdeb_autoremove'"
    fi
    
    local cache_files
    cache_files=$(find /var/cache/apt/archives -name "*.deb" | wc -l)
    if [ "$cache_files" -gt 100 ]; then
        echo "💡 $cache_files cached packages - consider running 'jwdeb_autoclean'"
    fi
    
    if [ -n "$broken_check" ]; then
        echo "💡 Package issues detected - run 'jwdeb_fix' to attempt repair"
    fi
    
    echo
}
