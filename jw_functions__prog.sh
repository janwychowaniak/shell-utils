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

jwpycallgraph ()
{
  echo
  echo '  pycallgraph  graphviz -- ./testing.py '
  echo '  pycallgraph --exclude "logging*" --exclude "unittest*" --exclude "re*" --exclude "sre_*" graphviz -- ./testing.py '
  echo '  pycallgraph --include "pkg_srv*" --include "pkg_shared*" --include "*module*" --exclude "unittest*" graphviz -- ./testing.py'
  echo
}

jwpyreverse ()
{
  echo
  echo '  pyreverse -o png -p project_name ./testing.py'
  echo
}

