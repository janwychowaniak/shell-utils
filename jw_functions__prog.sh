# A collection of miscellaneous tools and convenience functions that are helpful for some programming related tasks.
# Some are just notes on how to use certain tools.


jwcincludegraph()
{
    jwcinclude2dot > includegraph.$$.dot
    dot -Tps includegraph.$$.dot > includegraph.$$.ps
    convert -density 300 includegraph.$$.ps  includegraph.$$.jpg
    convert includegraph.$$.jpg -resize 50% includegraph.$$.png
    rm includegraph.$$.dot includegraph.$$.jpg includegraph.$$.ps
}

jwcoflo()
{
    # C and C++ Control Flow Graph Generator and Analyzer
    # [http://coflo.sourceforge.net]
    if [ $# -lt 1 ]
    then
        local NAZWA="NAZWA"
    else
        local NAZWA=$1
    fi
    echo "~/applications/coflo/bin/coflo $NAZWA.cpp --cfg=main --cfg-fmt=img -o temp_$$.png &&"
    echo "rm temp_$$.png &&"
    echo "~/applications/coflo/dot_rm.py temp_$$.dot > $NAZWA.dot &&"
    echo "dot -Tpng $NAZWA.dot -o $NAZWA.png &&"
    echo "eom $NAZWA.png"
}

# python ####################################################################################################################################
#
jwpycallgraph ()
{
    FILEPARAM=${1:-SCRIPT.py}
    echo
    echo "  # (pip3 install pycallgraph)"
    echo "  # [docs: http://pycallgraph.slowchop.com/]"
    echo
    echo "pycallgraph  graphviz -- $FILEPARAM "
    echo "pycallgraph --exclude \"logging*\" --exclude \"unittest*\" --exclude \"re*\" --exclude \"sre_*\" graphviz -- $FILEPARAM "
    echo "pycallgraph --include \"pkg_srv*\" --include \"pkg_shared*\" --include \"*module*\" --exclude \"unittest*\" graphviz -- $FILEPARAM"
    echo
}

jwpyreverse ()
{
    FILEPARAM=${1:-SCRIPT.py}
    PROJECTPARAM=${1:-PROJECT_NAME}
    PROJECTPARAM_NOEXT=`basename $PROJECTPARAM .py`
    echo
    echo '  # UML diagram generator from pylint3.'
    echo
    echo "pyreverse3 -o png -p ${PROJECTPARAM_NOEXT^^} $FILEPARAM"
    echo
}

jwpyan ()
{
    INPUTPARAM=${1:-*.py}
    OUTPUTPARAM=${1:-OUTPUT}
    OUTPUTPARAM_NOEXT=`basename $OUTPUTPARAM .py`
    OUTPUTPARAM_NOEXT_UPP=${OUTPUTPARAM_NOEXT^^}
    echo
    echo '  # Approximate call graphs for Python programs based on a (rather superficial) static analysis.'
    echo '  # [https://github.com/davidfraser/pyan]'
    echo '  # [git clone https://github.com/davidfraser/pyan.git]'
    echo
    echo "pyan.py $INPUTPARAM --uses --no-defines --colored --grouped --annotated --dot > $OUTPUTPARAM_NOEXT_UPP.dot"
    echo "dot -Tsvg $OUTPUTPARAM_NOEXT_UPP.dot > $OUTPUTPARAM_NOEXT_UPP.svg"
    echo "rm $OUTPUTPARAM_NOEXT_UPP.dot"
    echo
}

jwautopep8 ()
{
    FILEPARAM=${1:-SCRIPT.py}
    echo
    echo '  # PEP8-style formatter.'
    echo '  # [https://github.com/hhatto/autopep8]'
    echo
    echo "autopep8 --in-place --aggressive $FILEPARAM"
    echo "autopep8 --in-place --aggressive --aggressive $FILEPARAM"
    echo
}
#
#############################################################################################################################################

jwgituserconf ()
{
    cat 1>&2 <<'EOF'

# This is Git's per-user configuration file.
# (od Maćka A.)
[user]
    email =
    name =
[includeif "gitdir:~/dev/work/"]
    path = .gitconfig.work
[alias]
    ci = commit
    autoci = "!f() { for i in $(seq $1);\
do \
    msg=$(curl -s https://whatthecommit.com/index.txt); \
    git commit --allow-empty -m \"$msg\"; \
done \
}; f"

EOF
}

jwgitclean ()
{
    if [ -f ".gitignore" ]
    then
        while read line; do echo "rm -r $line ;" ; done < .gitignore
        echo "rm .gitignore ;"
    else
        echo "no '.gitignore'"
    fi
    echo

    find . -name ".gitignore" -exec echo "# -> {}" \; | grep --color=auto --color=ALWAYS ".gitignore"
}
