# A collection of miscellaneous tools and convenience functions that are helpful for some programming related tasks.
# Some are just notes on how to use certain tools.


alias jwpyl__pylint3-dRC="pylint3 -d R,C"

# --------------------------------------------------------


# C and C++ #################################################################################################################################
#
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
#
# python ####################################################################################################################################
#
jwvec__create-virtualenv() {
  # Create and configure a Python virtual environment with optional package installation.
  #
  # Usage: jwvec__create-virtualenv [ENV_NAME] [REQ_FILES...]
  #
  # This function creates a Python virtual environment in the current directory and
  # optionally installs packages from specified requirements files.
  #
  # Arguments:
  #   ENV_NAME (optional): Name for the virtual environment (default: 'venv').
  #   REQ_FILES (optional): One or more requirement files to install packages from.
  #
  # If no environment name is provided, the default name 'venv' is used. If no
  # requirement files are specified, it defaults to 'requirements.txt'. The function
  # checks for the existence of the specified environment name or requirements files
  # before creating or installing, ensuring there are no naming conflicts.
  #
  # Example usage:
  #   jwvec__create-virtualenv                              # Create 'venv' and install packages from 'requirements.txt'
  #   jwvec__create-virtualenv myenv                        # Create 'myenv' and install packages from 'requirements.txt'
  #   jwvec__create-virtualenv customenv req1.txt req2.txt  # Create 'customenv' and install packages from 'req1.txt' and 'req2.txt'
  #
  # Note: This function assumes 'python3' and 'pip' are available on the system.
  #
  # Returns:
  #   0: Success
  #   1: Error (e.g., environment name or requirements file conflict)

  local venv_name="${1:-venv}"  # Use the provided argument or 'venv' as the default
  local req_files=("${@:2}")    # Get additional arguments as requirement files

  # Check if an object with the given name exists
  if [ -e "$venv_name" ]; then
    echo "Error: An object with the name '$venv_name' already exists. Choose a different environment name."
    return 1  # Return an error code
  fi

  # Create the virtual environment
  echo "Creating virtual environment: $venv_name"
  python3 -m venv "$venv_name"

  # Check if any requirements files were provided
  if [ ${#req_files[@]} -eq 0 ]; then
    req_files=("requirements.txt")  # Use 'requirements.txt' as default if none provided
  fi

  # Activate the virtual environment
  source "$venv_name/bin/activate"

  # Install packages from specified requirements files
  for req_file in "${req_files[@]}"; do
    if [ -f "$req_file" ]; then
      echo
      echo "From $req_file:"
      python3 -m pip install -r "$req_file"
    else
      echo "Warning: Requirements file '$req_file' not found (in case any is expected)."
    fi
  done
}

jwvea__activate-virtualenv() {
  local venv_name="${1:-venv}"  # Use the provided argument or 'venv' as the default
  source "$venv_name/bin/activate"
}

# ---

jwpyc__pycallgraph()
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

jwpyr__pyreverse()
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

jwpya__pyan()
{
    INPUTPARAM=${@:-*.py}
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

jwpy8__autopep8()
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
# git #######################################################################################################################################
#
jwgiu__git-user-config()
{
    cat 1>&2 <<'EOF'

# This is Git's per-user configuration file example bits (~/.gitconfig).
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

jwgic__git-clean-ignored()
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
#
#############################################################################################################################################
