jwgoogle()
{
cat 1>&2 <<'EOF'

 older_than:1d
 newer_than:1d
 newer_than:3d  older_than:2d 
 after:2016/12/31  before:2017/1/7
 after:2017/2/8  before:2017/2/9         <- dokladnie z 8-go

 after:2016/1/1   before:2017/1/1         <- caly 2016
 after:2016/12/1  before:2017/1/1         <- caly grudzien 2016

EOF

}


jwtvnames() {
  DATEHASH=`date +%Y%m%d`
  SEED=$(( ( RANDOM % 100000 ) + 10000 ))
  NUMER="$DATEHASH$SEED"
  echo "skocznie-$NUMER"
  echo "schodki-$NUMER"
  echo "kanaly-$NUMER"
  echo "hidden-$NUMER"
  echo "inne-$NUMER"
  echo "kilka-$NUMER"
  echo "zagranie-$NUMER"
}

jwtvcrop() {
  case $# in
  "0")
    echo " *** " $FUNCNAME "arg[s]"
  ;;
  "1")
    local PLIK_IN=$1
    local PLIK_TEMP="$$-"$PLIK_IN
    convert $PLIK_IN -crop 1812x823+56+165 $PLIK_TEMP
    mv $PLIK_TEMP $PLIK_IN
  ;;
  *)
    for p in $@
    do
      echo $p
      local PLIK_IN=$p
      local PLIK_TEMP="$$-"$PLIK_IN
      convert $PLIK_IN -crop 1812x823+56+165 $PLIK_TEMP
      mv $PLIK_TEMP $PLIK_IN
    done
  ;;
  esac
}

