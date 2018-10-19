jwodspacjacz ()
{
    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

./$FUNCNAME

    Przebiega nazwy przedmiotow (plikow, folderow) z biezacej sciezki i podmienia spacje na \"_\"
    we WSZYSTKICH (z backupami (\"~\"), ale bez ukrytych) przedmiotach w folderze.

EOF
return 1
    fi

    for plik in *
    do
        nowa_nazwa=`echo $plik | sed "s/ /_/g"`
        if [ "$plik" != "$nowa_nazwa" ]
        then
            mv -i -v "$plik" "$nowa_nazwa"
        fi
    done
}

jwodspacjaczRekursywny()
{
    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

./$FUNCNAME

	Skrypt odspacjowywuje nazwy plikow i katalogow od biezacej lokalizacji rekursywnie w dol.

EOF
return 1
    fi

    jwodspacjacz
    ls -1 | while read plikLubFolder; do
        if [ -d "$plikLubFolder" ]; then
            cd "$plikLubFolder"
            jwodspacjaczRekursywny
            cd ..
        fi
    done
}


jwfind ()
{

    if [ $# -ne 1 ]
    then
cat 1>&2 <<EOF

./`basename $0` CO_ZNALEZC

    Skrypt jest wrapperem na 'find', przeszukuje odtad (.) rekursywnie w dol,
    za plikiem, ktorego nazwa zawiera argument.
    Przeszukiwanie jest case-INsensytywne.

EOF
return 1
    fi

    if [ $# -eq 1 ] && ([ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ])
    then
cat 1>&2 <<EOF

./`basename $0` CO_ZNALEZC

    Skrypt jest wrapperem na 'find', przeszukuje odtad (.) rekursywnie w dol,
    za plikiem, ktorego nazwa zawiera argument.
    Przeszukiwanie jest case-INsensytywne.

EOF
return 1
    fi

    SZUKANE=$1
    find . -iname \*"$SZUKANE"\* | grep --color=ALWAYS -i "$SZUKANE"    # podswietlanie
}


jwbatchmv ()
{
    if [ $# -ne 1 ] && [ $# -ne 2 ]
    then
cat 1>&2 <<EOF

$FUNCNAME fraza [nowa fraza]

    Przebiega nazwy plikow z biezacej sciezki i modyfikuje nazwy, podana fraze w nich usuwajac (przy jednym argumencie) lub zamieniajac (przy dwoch).

EOF
return 1
    fi


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# czy nie ma spacji w nazwie zadnego pliku
    ls | grep [[:space:]] > /dev/null
    if [ $? -eq 0 ]
    then
        echo " *** Nazwy plikow zawieraja spacje, pierdole: `pwd`" >&2
        return 2
    fi
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


    STARA_FRAZA="$1"
    NOWA_FRAZA="$2"

    if [ "$STARA_FRAZA" == "$NOWA_FRAZA" ]
    then
        echo " *** $STARA_FRAZA -> $NOWA_FRAZA ???" >&2
        return 3
    fi

    PLIKI_ZE_STARA_FRAZA=`ls | grep "$STARA_FRAZA"`
    for plik in $PLIKI_ZE_STARA_FRAZA
    do
        mv -i -v $plik `echo $plik | sed "s/$STARA_FRAZA/$NOWA_FRAZA/g"`
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

    Przebiega nazwy plikow z biezacej sciezki i modyfikuje nazwy, usuwajac z nich wszystkie polskie ogonki.

EOF
return 1
    fi

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# czy nie ma spacji w nazwie zadnego pliku
    ls | grep [[:space:]] > /dev/null
    if [ $? -eq 0 ]
    then
        echo " *** Nazwy plikow zawieraja spacje, pierdole: `pwd`" >&2
        return 2
    fi
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    A=ą; _A=a; AA=Ą; _AA=A;
    C=ć; _C=c; CC=Ć; _CC=C;
    E=ę; _E=e; EE=Ę; _EE=E;
    L=ł; _L=l; LL=Ł; _LL=L;
    N=ń; _N=n; NN=Ń; _NN=N;
    O=ó; _O=o; OO=Ó; _OO=O;
    S=ś; _S=s; SS=Ś; _SS=S;
    Z1=ź; _Z1=z; ZZ1=Ź; _ZZ1=Z;
    Z2=ż; _Z2=z; ZZ2=Ż; _ZZ2=Z;

    for plik in *
    do
        odpol_plik=$plik
        odpol_plik=`echo $odpol_plik | sed "s/$A/$_A/g" | sed "s/$AA/$_AA/g"`
        odpol_plik=`echo $odpol_plik | sed "s/$C/$_C/g" | sed "s/$CC/$_CC/g"`
        odpol_plik=`echo $odpol_plik | sed "s/$E/$_E/g" | sed "s/$EE/$_EE/g"`
        odpol_plik=`echo $odpol_plik | sed "s/$L/$_L/g" | sed "s/$LL/$_LL/g"`
        odpol_plik=`echo $odpol_plik | sed "s/$N/$_N/g" | sed "s/$NN/$_NN/g"`
        odpol_plik=`echo $odpol_plik | sed "s/$O/$_O/g" | sed "s/$OO/$_OO/g"`
        odpol_plik=`echo $odpol_plik | sed "s/$S/$_S/g" | sed "s/$SS/$_SS/g"`
        odpol_plik=`echo $odpol_plik | sed "s/$Z1/$_Z1/g" | sed "s/$ZZ1/$_ZZ1/g"`
        odpol_plik=`echo $odpol_plik | sed "s/$Z2/$_Z2/g" | sed "s/$ZZ2/$_ZZ2/g"`
        if [ "$plik" != "$odpol_plik" ]
        then
            mv -i -v "$plik" "$odpol_plik"
        fi
    done
}


jwfindplchars ()
{
    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

$FUNCNAME

    Skrypt nic nie zmienia.
    Wyszukuje jeno (find) pliki z nazwami zawierajacymi polskie ogonki: ąćęłńóśźż i ĄĆĘŁŃÓŚŹŻ

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

    Skrypt nic nie zmienia.
    Wyszukuje jeno (find) pliki z nazwami zawierajacymi [](){}^=\$!+~\`@#%&;'\:*?"<>|

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

    echo && echo "---------------------------------"
                                               # windi windi
    echo && echo '\' && find . -iname '*\\*'   #
    echo && echo ':' && find . -iname '*:*'    #
    echo && echo '*' && find . -iname '*\**'   #
    echo && echo '?' && find . -iname '*\?*'   #
    echo && echo '"' && find . -iname '*"*'    #
    echo && echo '<' && find . -iname '*<*'    #
    echo && echo '>' && find . -iname '*>*'    #
    echo && echo '|' && find . -iname '*|*'    #

    echo
}


jwfindeachars ()
{
  for c in "Ç" "ü" "é" "â" "ä" "à" "å" "ç" "ê" "ë" "è" "ï" "î" "ì" "Ä" "Å" "É" "æ" "Æ" "ô" "ö" "ò" "û" "ù" "ÿ" "Ö" "Ü" "ø" "£" "Ø" "×" "ƒ" "á" "í" "ó" "ú" "ñ" "Ñ" "ª" "º" "¿" "®" "¬" "½" "¼" "¡" "«" "»" "░" "▒" "▓" "│" "┤" "Á" "Â" "À" "©" "╣" "║" "╗" "╝" "¢" "¥" "┐" "└" "┴" "┬" "├" "─" "┼" "ã" "Ã" "╚" "╔" "╩" "╦" "╠" "═" "╬" "¤" "ð" "Ð" "Ê" "Ë" "È" "ı" "Í" "Î" "Ï" "┘" "┌" "█" "▄" "¦" "Ì" "▀" "Ó" "ß" "Ô" "Ò" "õ" "Õ" "µ" "þ" "Þ" "Ú" "Û" "Ù" "ý" "Ý" "¯" "´" "≡" "±" "‗" "¾" "¶" "§" "÷" "¸" "°" "¨" "·" "¹" "³" "²" "■"
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



jwscanexts ()
{
  find . -type f | perl -ne 'print $1 if m/\.([^.\/]+)$/' | sort -u
}


jwwysyp () 
{ 
  for p in `ls`;
  do
    [ -d "$p" ] && mv "$p"/* . && rmdir "$p";
  done
}


jwlabelhere () 
{ 
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
  local FNUM=`find . -type f | wc -l`
  local DNUM=`find . -type d | wc -l`
  echo "files     : $FNUM"
  echo "folders   : $DNUM"
  echo "du -sh .  : `du -sh .`"
  echo "du -sBM . : `du -sBM .`"
}

jwstats_l () 
{ 
    local FNUM=`find . -type f | wc -l`;
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


jwbackupfile ()
{

  local SUFFIX="`date +%Y-%m-%d_%H:%M:%S`__.BAK"

  case $# in
  "0")
    echo " *** " $FUNCNAME "arg[s]"
  ;;
  *)
    for p in $@
    do
      cp -v "$p" "$p"__$SUFFIX
    done
  ;;
  esac

}

