# A collection of miscellaneous file naming manipulation and file system related functions


jwdiff() {
    wdiff -n $1 $2 | colordiff
}

jwodspacjacz ()
{
    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

$FUNCNAME

    A simple function that removes whitespaces from the names of all files and folders
    from the current location. Each whitespace occurrence is replaced with "_".
    Does not affect items, the names of which already don't include whitespaces.
    Does not affect hidden items.

EOF
        return 1
    fi

    for old_name in *
    do
        new_name=`echo $old_name | sed "s/ /_/g"`
        if [ "$old_name" != "$new_name" ]
        then
            mv -i -v "$old_name" "$new_name"
        fi
    done
}

jwodspacjaczRekursywny()
{
    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

$FUNCNAME

    A simple function that removes whitespaces from the names of all files and folders from
    the current location AND recursively down. Each whitespace occurrence is replaced with "_".
    Does not affect items, the names of which already don't include whitespaces.
    Does not affect hidden items.

EOF
        return 1
    fi

    jwodspacjacz
    ls -1 | while read fsitem; do
        if [ -d "$fsitem" ]; then
            cd "$fsitem"
            jwodspacjaczRekursywny
            cd ..
        fi
    done
}


jwbatchmv ()
{
    if [ $# -ne 1 ] && [ $# -ne 2 ]
    then
cat 1>&2 <<EOF

$FUNCNAME PHRASE [NEW_PHRASE]

    A simple function for performing batch rename of files and folders from the current location.
    With a single argument given it removes that phrase from all the names where it finds it.
    If two arguments given, it substitutes the first one for the other.

EOF
        return 1
    fi


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  the function assumes the names don't contain whitespaces, this section makes sure of it
    ls | grep [[:space:]] > /dev/null
    if [ $? -eq 0 ]
    then
        echo " *** Filenames containing whitespaces found, aborting: `pwd`" >&2
        return 2
    fi
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


    local OLDPHRASE="$1"
    local NEWPHRASE="$2"

    if [ "$OLDPHRASE" == "$NEWPHRASE" ]
    then
        echo " *** $OLDPHRASE -> $NEWPHRASE ???" >&2
        return 3
    fi

    FILES_WITH_OLDPHRASE=`ls | grep "$OLDPHRASE"`
    for p in $FILES_WITH_OLDPHRASE
    do
        mv -i -v $p `echo $p | sed "s/$OLDPHRASE/$NEWPHRASE/g"`
    done
}


jwbatchunpl()
{
    ### ~ 1lvl down effect: ~ ################################################################
    ### for f in `ls` ; do [ -d "$f" ] && cd "$f" && jwbatchunpl && cd - >/dev/null ; done ###
    ##########################################################################################

    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

$FUNCNAME

    A simple function for performing batch removal of Polish-specific letters
    from the names of files and folders from the current location.

EOF
        return 1
    fi

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  the function assumes the names don't contain whitespaces, this section makes sure of it
    ls | grep [[:space:]] > /dev/null
    if [ $? -eq 0 ]
    then
        echo " *** Filenames containing whitespaces found, aborting: `pwd`" >&2
        return 2
    fi
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    A=ą; _A=a; AA=Ą; _AA=A;
    C=ć; _C=c; CC=Ć; _CC=C;
    E=ę; _E=e; EE=Ę; _EE=E;
    L=ł; _L=l; LL=Ł; _LL=L;
    N=ń; _N=n; NN=Ń; _NN=N;
    O=ó; _O=o; OO=Ó; _OO=O;
    S=ś; _S=s; SS=Ś; _SS=S;
    Z1=ź; _Z1=z; ZZ1=Ź; _ZZ1=Z;
    Z2=ż; _Z2=z; ZZ2=Ż; _ZZ2=Z;

    for fsitem in *
    do
        unpl_fsitem=$fsitem
        unpl_fsitem=`echo $unpl_fsitem | sed "s/$A/$_A/g" | sed "s/$AA/$_AA/g"`
        unpl_fsitem=`echo $unpl_fsitem | sed "s/$C/$_C/g" | sed "s/$CC/$_CC/g"`
        unpl_fsitem=`echo $unpl_fsitem | sed "s/$E/$_E/g" | sed "s/$EE/$_EE/g"`
        unpl_fsitem=`echo $unpl_fsitem | sed "s/$L/$_L/g" | sed "s/$LL/$_LL/g"`
        unpl_fsitem=`echo $unpl_fsitem | sed "s/$N/$_N/g" | sed "s/$NN/$_NN/g"`
        unpl_fsitem=`echo $unpl_fsitem | sed "s/$O/$_O/g" | sed "s/$OO/$_OO/g"`
        unpl_fsitem=`echo $unpl_fsitem | sed "s/$S/$_S/g" | sed "s/$SS/$_SS/g"`
        unpl_fsitem=`echo $unpl_fsitem | sed "s/$Z1/$_Z1/g" | sed "s/$ZZ1/$_ZZ1/g"`
        unpl_fsitem=`echo $unpl_fsitem | sed "s/$Z2/$_Z2/g" | sed "s/$ZZ2/$_ZZ2/g"`
        if [ "$fsitem" != "$unpl_fsitem" ]
        then
            mv -i -v "$fsitem" "$unpl_fsitem"
        fi
    done
}


jwscanexts ()
{

    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

$FUNCNAME

    Prints all the extensions, that the files in the current location and recursively down end with.
    Scans the subtree for file types, in other words.

EOF
        return 1
    fi

    find . -type f | perl -ne 'print $1 if m/\.([^.\/]+)$/' | sort -u

}


jwwysyp () 
{
    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

$FUNCNAME

    The function reaches into all the directories in the current location, brings their contents
    one level up (i.e. to the current location), then deletes those now empty directories.
    The directory structures having existed within all that directories, from their level down, are preserved.

EOF
        return 1
    fi

    for p in `ls`;
    do
        [ -d "$p" ] && mv "$p"/* . && rmdir "$p";
    done
}


jwlabelhere () 
{ 

    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

$FUNCNAME

    The function prepends the names of all the files and directories
    in the current location with the name of the current directory.

EOF
        return 1
    fi

    ### ~ mass effect: ~ ##########################################################
    ### for f in `ls` ; do [ -d "$f" ] && cd "$f" && jwlabelhere && cd - ; done ###
    ###############################################################################
    for p in `ls`;
    do
        mv $p "$(basename `pwd`)__$p";
    done

}


jwstats ()
{
    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

$FUNCNAME

    The function presents some basic statistics of the current location:
    the number files and directories in the subtree, as well as the disk space they occupy combined.

EOF
        return 1
    fi

    local FNUM=`find . -type f | wc -l`
    local DNUM=`find . -type d | wc -l`
    echo "files     : $FNUM"
    echo "folders   : $DNUM"
    echo "du -sh .  : `du -sh .`"
    echo "du -sBM . : `du -sBM .`"

}

jwstatsl () 
{

    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

$FUNCNAME

    The function presents some basic statistics of the current location:
    the number files and directories in the subtree, as well as the disk space they occupy combined.
    Additionally, each item in the current location prints its own size information.

EOF
        return 1
    fi

    local FNUM=`find . -type f | wc -l`; # TODO: duplicates code from jwstats
    local DNUM=`find . -type d | wc -l`;
    echo "files     : $FNUM";
    echo "folders   : $DNUM";
    echo "du -sh .  : `du -sh .`";
    echo "du -sBM . : `du -sBM .`"
    echo
    du -ssBM *

}


jw1leveldeepfoldermielenie ()
{
cat 1>&2 <<'EOF'

  for p in `ls`; do [ -d "$p" ] && cd $p && MIELENIE && cd - > /dev/null ; done

EOF
}


jwbackupfile () {
  local TS=$(date +%Y%m%d)
  local SUFFIX="--$TS.JWBAK"

  if [ $# -eq 0 ]; then
    printf " *** %s arg[s]\n" "$FUNCNAME"
    printf " Backups the given file, appending the name with current date and time.\n"
    return 1
  fi

  for p in "$@"; do
    printf "cp -a %s %s%s\n" "$p" "$p" "$SUFFIX"
  done
}



# ----------------------------------------------------------------------------------------
# --------------- finders ----------------------------------------------------------------
# ----------------------------------------------------------------------------------------

jwfind ()
{

    if [ $# -ne 1 ] || ([ $# -eq 1 ] && ([ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ]))
    then
cat 1>&2 <<EOF

$FUNCNAME SEARCHED_PHRASE

    A convenience wrapper for the "find" program. Starts from the current location and searches
    recursively down for items, the names of which include the given phrase.
    The search is case insensitive.

EOF
        return 1
    fi

    SEARCHEDFOR=$1
    find . -iname \*"$SEARCHEDFOR"\* | grep --color=ALWAYS -i "$SEARCHEDFOR"    # "--color=ALWAYS" gives highlightingof the match
}


# ------------------------------

jwfindplchars ()
{
    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

$FUNCNAME

    This function searches for files and folders, the names of which contain Polish-specific letters.
    The search is performed from the current location recursively down. No changes are made.

EOF
        return 1
    fi

    echo && echo 'ą' && find . -name '*ą*'
    echo && echo 'ć' && find . -name '*ć*'
    echo && echo 'ę' && find . -name '*ę*'
    echo && echo 'ł' && find . -name '*ł*'
    echo && echo 'ń' && find . -name '*ń*'
    echo && echo 'ó' && find . -name '*ó*'
    echo && echo 'ś' && find . -name '*ś*'
    echo && echo 'ź' && find . -name '*ź*'
    echo && echo 'ż' && find . -name '*ż*'

    echo && echo 'Ą' && find . -name '*Ą*'
    echo && echo 'Ć' && find . -name '*Ć*'
    echo && echo 'Ę' && find . -name '*Ę*'
    echo && echo 'Ł' && find . -name '*Ł*'
    echo && echo 'Ń' && find . -name '*Ń*'
    echo && echo 'Ó' && find . -name '*Ó*'
    echo && echo 'Ś' && find . -name '*Ś*'
    echo && echo 'Ź' && find . -name '*Ź*'
    echo && echo 'Ż' && find . -name '*Ż*'
}


jwfindspecchars()
{
    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

$FUNCNAME

    This function searches for files and folders, the names of which contain special characters.
    [](){}^=\$!+~\`@#%&;'\:*?"<>|
    The search is performed from the current location recursively down. No changes are made.

EOF
return 1
    fi

    # man fnmatch
    echo && echo '[' && find . -iname '*\[*'
    echo && echo ']' && find . -iname '*\]*'

    echo && echo '(' && find . -iname '*(*'
    echo && echo ')' && find . -iname '*)*'
    echo && echo '{' && find . -iname '*{*'
    echo && echo '}' && find . -iname '*}*'
    echo && echo '^' && find . -iname '*^*'
    echo && echo '=' && find . -iname '*=*'
    echo && echo '$' && find . -iname '*$*'
    echo && echo '!' && find . -iname '*!*'
    echo && echo '+' && find . -iname '*+*'
    echo && echo '~' && find . -iname '*~*'
    echo && echo '`' && find . -iname '*`*'
    echo && echo '@' && find . -iname '*@*'
    echo && echo '#' && find . -iname '*#*'
    echo && echo '%' && find . -iname '*%*'
    echo && echo '&' && find . -iname '*&*'
    echo && echo ';' && find . -iname '*;*'

    echo && echo "'" && find . -iname "*'*"

    echo && echo "---------- Windows-critical: ----------"

    echo && echo '\' && find . -iname '*\\*'
    echo && echo ':' && find . -iname '*:*' 
    echo && echo '*' && find . -iname '*\**'
    echo && echo '?' && find . -iname '*\?*'
    echo && echo '"' && find . -iname '*"*' 
    echo && echo '<' && find . -iname '*<*' 
    echo && echo '>' && find . -iname '*>*' 
    echo && echo '|' && find . -iname '*|*' 

    echo
}


jwfindeachars ()
{

    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

$FUNCNAME

    This function searches for files and folders, the names of which contain special extended-ASCII characters.
        ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜø£Ø×ƒáíóúñÑªº¿®¬½¼¡«»░▒▓│┤ÁÂÀ©╣║╗╝¢¥
        ┐└┴┬├─┼ãÃ╚╔╩╦╠═╬¤ðÐÊËÈıÍÎÏ┘┌█▄¦Ì▀ÓßÔÒõÕµþÞÚÛÙýÝ¯´≡±‗¾¶§÷¸°¨·¹³²■
    The search is performed from the current location recursively down. No changes are made.

EOF
        return 1
    fi

    for c in \
        "Ç" "ü" "é" "â" "ä" "à" "å" "ç" "ê" "ë" "è" "ï" "î" "ì" "Ä" "Å" "É" "æ" "Æ" "ô" \
        "ö" "ò" "û" "ù" "ÿ" "Ö" "Ü" "ø" "£" "Ø" "×" "ƒ" "á" "í" "ó" "ú" "ñ" "Ñ" "ª" "º" \
        "¿" "®" "¬" "½" "¼" "¡" "«" "»" "░" "▒" "▓" "│" "┤" "Á" "Â" "À" "©" "╣" "║" "╗" \
        "╝" "¢" "¥" "┐" "└" "┴" "┬" "├" "─" "┼" "ã" "Ã" "╚" "╔" "╩" "╦" "╠" "═" "╬" "¤" \
        "ð" "Ð" "Ê" "Ë" "È" "ı" "Í" "Î" "Ï" "┘" "┌" "█" "▄" "¦" "Ì" "▀" "Ó" "ß" "Ô" "Ò" \
        "õ" "Õ" "µ" "þ" "Þ" "Ú" "Û" "Ù" "ý" "Ý" "¯" "´" "≡" "±" "‗" "¾" "¶" "§" "÷" "¸" \
        "°" "¨" "·" "¹" "³" "²" "■"
    do
        find . -name "*$c*"
    done

}


jwfindstrangechars ()
{
cat 1>&2 <<'EOF'

  find . -name "*[^-a-z\!A-Z_.(),0-9'\[\]]*"
  find . -name "*[^-a-z\!A-Z_.(),0-9'\[\]%+=]*"

EOF
}


# ------------------------------

jwfindnewestfiles() {
    # [https://www.shellhacks.com/bash-colors/]
    # [https://misc.flogisoft.com/bash/tip_colors_and_formatting]
    if [ $# -ne 0 ] && [ $# -ne 1 ]
    then
cat 1>&2 <<EOF

$FUNCNAME  [top_results]

    This function searches for files only, ordering results by modification time,
    then displaying a couple of the MOST recently modified.
    The search is performed from the current location recursively down. No changes are made.

EOF
        return 1
    fi

    #
    local white="\e[1;37m"
    local wnc="\e[0m"
    local dgrey="\e[2m"
    local dgwnc="\e[22m"
    #

    local TARGETS=`find . -type f -printf "%T@ %TY-%Tm-%Td %TT  %p\n" | sort -nr | cut -d' ' -f 2- | head -n 1`
    local TARGETS_NAME=`echo $TARGETS | awk '{print $3}'`
    local TARGETS_MTIME_D=`echo $TARGETS | awk '{print $1}'`
    local TARGETS_MTIME_Thms=`echo $TARGETS | awk '{print $2}' | cut -d'.' -f 1`
    local TARGETS_MTIME_Tss=`echo $TARGETS | awk '{print $2}' | cut -d'.' -f 2`
    local TARGETS_MTIME_Tss3=`echo $(expr substr "${TARGETS_MTIME_Tss}" 1 3)`

    local TOPX=${1:-8}

    echo -en "Top result: $white$TARGETS_NAME$wnc  "
    echo -e "[$white$TARGETS_MTIME_D$wnc $TARGETS_MTIME_Thms$dgrey.$TARGETS_MTIME_Tss3$dgwnc]"

    echo "------- <top $TOPX>:"
    find . -type f -printf "%T@ [%TY-%Tm-%Td %TT]  %p\n" | sort -nr | cut -d' ' -f 2- | head -n $TOPX
}


jwfindoldestfiles() {
    # [https://www.shellhacks.com/bash-colors/]
    # [https://misc.flogisoft.com/bash/tip_colors_and_formatting]
    if [ $# -ne 0 ] && [ $# -ne 1 ]
    then
cat 1>&2 <<EOF

$FUNCNAME  [top_results]

    This function searches for files only, ordering results by modification time,
    then displaying a couple of the LEAST recently modified.
    The search is performed from the current location recursively down. No changes are made.

EOF
        return 1
    fi

    #
    local white="\e[1;37m"
    local wnc="\e[0m"
    local dgrey="\e[2m"
    local dgwnc="\e[22m"
    #

    local TARGETS=`find . -type f -printf "%T@ %TY-%Tm-%Td %TT  %p\n" | sort -n | cut -d' ' -f 2- | head -n 1`
    local TARGETS_NAME=`echo $TARGETS | awk '{print $3}'`
    local TARGETS_MTIME_D=`echo $TARGETS | awk '{print $1}'`
    local TARGETS_MTIME_Thms=`echo $TARGETS | awk '{print $2}' | cut -d'.' -f 1`
    local TARGETS_MTIME_Tss=`echo $TARGETS | awk '{print $2}' | cut -d'.' -f 2`
    local TARGETS_MTIME_Tss3=`echo $(expr substr "${TARGETS_MTIME_Tss}" 1 3)`

    local TOPX=${1:-8}

    echo -en "Top result: $white$TARGETS_NAME$wnc  "
    echo -e "[$white$TARGETS_MTIME_D$wnc $TARGETS_MTIME_Thms$dgrey.$TARGETS_MTIME_Tss3$dgwnc]"

    echo "------- <top $TOPX>:"
    find . -type f -printf "%T@ [%TY-%Tm-%Td %TT]  %p\n" | sort -n | cut -d' ' -f 2- | head -n $TOPX
}
