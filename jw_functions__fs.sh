# A collection of miscellaneous file naming manipulation and file system related functions


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


jwwysyp () 
{
    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

${FUNCNAME[0]}

    The function reaches into all the directories in the current location, brings their contents
    one level up (i.e. to the current location), then deletes those now empty directories.
    The directory structures having existed within all that directories, from their level down, are preserved.

EOF
        return 1
    fi

    if [ "$(pwd)" = "$HOME" ]; then echo "Don't use it in HOME!" && return; fi
    for p in *; do
        if [ -d "$p" ]; then
            if mv "$p"/* . 2>/dev/null; then
                rmdir "$p"
            else
                echo "Directory '$p' was empty."
                rmdir "$p"
            fi
        fi
    done
}
