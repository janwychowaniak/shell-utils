# A collection of media manipulation functions based on (or using) FFmpeg



############################
### purely ffprobe based ###
############################

jwffbitrateEXT() {
  EXT=$1

  leadingws=110;

  count=0;
  totalbr=0;
  totalsize=0;
  totaldur=0;

  for p in *.$EXT ; do

    ffpro_outp=$(ffprobe "$p" 2>&1 | grep Duration)
    fsize=$(du "$p" | awk "{ print ( \$1 ) }")

    printf "%$(echo $leadingws)s" "$p  ->"
    echo " "$ffpro_outp
    br=$(echo $ffpro_outp | awk "{ print ( \$(NF-1) ) }")
    durstr=$(echo $ffpro_outp | awk "{ print ( \$2 ) }")    # "00:01:07.87,"
    dursec=`python -c "import sys; DURSTR=sys.argv[1]; print sum(int(x) * 60 ** i for i,x in enumerate(reversed(DURSTR.split('.')[0].split(':'))))" $durstr`

    totalbr=$(echo $totalbr+$br | bc )
    totalsize=$(echo $totalsize+$fsize | bc )
    totaldur=$(echo $totaldur+$dursec | bc )
    ((count++))
  done

  avg=`echo "scale=0; $totalbr / $count" | bc`
  totalsizeM=`echo "scale=0; $totalsize / 1024" | bc`
  totaldurHMS=`python -c "import sys; TDURSEC=sys.argv[1]; m, s = divmod(int(TDURSEC), 60); h, m = divmod(m, 60); print \"%d:%02d:%02d\" % (h, m, s)" $totaldur`

  suffix=$(echo $ffpro_outp | awk "{ print ( \$(NF) ) }")
  ffprolen=`echo ${#ffpro_outp}`

  printf "%$(echo $leadingws)s" " "; printf '_%.0s' $(seq 1 $ffprolen); echo

  printf "%$(echo $leadingws+$ffprolen | bc )s" "avg: $avg $suffix"; echo
  printf "%$(echo $leadingws+$ffprolen | bc )s" "total size: $totalsizeM MB"; echo
  printf "%$(echo $leadingws+$ffprolen | bc )s" "total duration: $totaldurHMS"; echo
}

alias jwffbitrate='jwffbitrateEXT mp3'
alias jwffbitrate_mp3='jwffbitrateEXT mp3'
alias jwffbitrate_avi='jwffbitrateEXT avi'
alias jwffbitrate_m4a='jwffbitrateEXT m4a'
alias jwffbitrate_mkv='jwffbitrateEXT mkv'
alias jwffbitrate_mp4='jwffbitrateEXT mp4'
alias jwffbitrate_ogg='jwffbitrateEXT ogg'
alias jwffbitrate_ogv='jwffbitrateEXT ogv'
alias jwffbitrate_wav='jwffbitrateEXT wav'
alias jwffbitrate_webm='jwffbitrateEXT webm'


jwffmeanbitrateEXT () 
{ 
    EXT=$1;
    CWD=$(basename $(pwd))

    ls | grep $EXT$ > /dev/null

    if [ $? -ne 0 ]
    then           # brak plikow zakonczonych na EXT
        printf "... ....: $CWD";
        echo
        return
    fi

    COUNT=0;
    BRSUM=0;

    for p in *.$EXT;
    do
        FFPRO_OUTP=$(ffprobe "$p" 2>&1 | grep Duration);
        BR=$(echo $FFPRO_OUTP | awk "{ print ( \$(NF-1) ) }");
        BRSUM=$(echo $BRSUM+$BR | bc );
        ((COUNT++));
    done;

    BRAVG=`echo "scale=0; $BRSUM / $COUNT" | bc`;
    SUFFIX=$(echo $FFPRO_OUTP | awk "{ print ( \$(NF) ) }");

    printf "$BRAVG $SUFFIX: $CWD";
    echo
}

alias jwffmeanbitrate="jwffmeanbitrateEXT mp3"


jwffaudioparamsEXT() {
  EXT=$1
  leadingws=80;

  for p in *.$EXT ; do

    ffpro_outp=$(ffprobe "$p" 2>&1 | grep Audio)

    printf "%$(echo $leadingws)s" "$p  ->"
    echo " "$ffpro_outp

  done
}

alias jwffaudioparams='jwffaudioparamsEXT mp3'
alias jwffaudioparams_mp3='jwffaudioparamsEXT mp3'
alias jwffaudioparams_avi='jwffaudioparamsEXT avi'
alias jwffaudioparams_m4a='jwffaudioparamsEXT m4a'
alias jwffaudioparams_mkv='jwffaudioparamsEXT mkv'
alias jwffaudioparams_mp4='jwffaudioparamsEXT mp4'
alias jwffaudioparams_ogg='jwffaudioparamsEXT ogg'
alias jwffaudioparams_ogv='jwffaudioparamsEXT ogv'
alias jwffaudioparams_wav='jwffaudioparamsEXT wav'
alias jwffaudioparams_webm='jwffaudioparamsEXT webm'


jwffvideoparamsEXT() {
  EXT=$1
  leadingws=80;

  for p in *.$EXT ; do

    ffpro_outp=$(ffprobe "$p" 2>&1 | grep Video)

    printf "%$(echo $leadingws)s" "$p  ->"
    echo " "$ffpro_outp

  done
}

alias jwffvideoparams_avi='jwffvideoparamsEXT avi'
alias jwffvideoparams_mkv='jwffvideoparamsEXT mkv'
alias jwffvideoparams_mp4='jwffvideoparamsEXT mp4'
alias jwffvideoparams_ogv='jwffvideoparamsEXT ogv'
alias jwffvideoparams_webm='jwffvideoparamsEXT webm'


jwffprobe ()
{

  case $# in
  "0")
    echo " *** " $FUNCNAME "arg[s]"
  ;;
  "1")
    ffprobe "$1" 2>&1 | egrep "Duration|Stream"
  ;;
  *)
    for p in $@
    do
      echo $p:
      ffprobe "$p" 2>&1 | egrep "Duration|Stream"
      echo
    done
  ;;
  esac

}


jwffgetvideoresolution() 
{
  local FFOUT=`ffprobe -v quiet -print_format csv -show_streams -select_streams v $1 | awk -F "," '{print $10 " " $11}'`
  if [ $# -eq 1 ]; then
    echo $FFOUT
  elif [ $# -eq 2 ]; then
    local WIDTH=`echo $FFOUT | awk '{print $1}'`
    local HEIGHT=`echo $FFOUT | awk '{print $2}'`
    local NEWWIDTH=$2
    local NEWHEIGHT=`echo "$NEWWIDTH * $HEIGHT / $WIDTH" | bc`
    [ `echo $NEWHEIGHT%2 | bc` -ne 0 ] && let NEWHEIGHT="$NEWHEIGHT-1"	# round to even (for x264)
    echo "$NEWWIDTH":"$NEWHEIGHT"
  else
    echo "getvideoresolution name [desired-width]"
  fi
}

jwffrozdzialki ()
{
  for e in `ls` ; do echo -en "$e " ; ffprobe $e 2>&1 | grep -o '[0-9]\{3,4\}x[0-9]\{3,4\}' ; done
}



###################################
### ffmpeg {,and ffprobe} based ###
###################################

jwffmpeg-rozne ()
{
cat <<'EOF'

MP4 -> AVI z kontrola jakosci:
 ffmpeg -i input.mp4 -q:v 0                        -q:a 0                 output.avi
 ffmpeg -i input.mp4 -q:v 0 -vf scale=960:-1 -r 25 -q:a 0 -ar 24000 -ac 1 output.avi
lektura o doborze qscale: http://www.kilobitspersecond.com/2007/05/24/ffmpeg-quality-comparison/:
 autor: 5, *9*, 11
 koment: 4, 8, 10
 ffmpeg -i input.avi -map 0:0 -map 0:1 -qscale 8 -r 25 -ar 32000 -ab 96k -s 1024x576 output.avi


obrazki:
MP4 -> JPG (15/s):
 ffmpeg -i input.mp4 -q:v 0 -r 15 -f image2 image-%3d.jpg
nazad przeistoczenie:
 ffmpeg -i input-%05d.jpg -r 15 -q:v 2 output.mpeg

montaz video poklatkowego z arbitralnych obrazkow:
 ffmpeg -framerate 2 -i klatka_%05d.jpg -q:v 0 -r 30 output.mpeg
 ffmpeg -i output.mpeg -q:v 0 output.avi
 rm output.mpeg


przyspieszenie:
tempo, samo video:
 ffmpeg -i input.avi -q:v 0 -vf "setpts=0.5*PTS" output_x2.avi
sterowanie offsetem (ss) i dlugoscia (t) wyniku:
 ffmpeg -ss 23 -t 40 -i input.mp4 -vf "setpts=0.125*PTS" -qscale 0 output_x8.avi
przyspieszenie zgodnie audio i video (x1.6 i x2):
 ffmpeg -i audiovideo.avi -filter_complex "[0:v]setpts=0.625*PTS[v];[0:a]atempo=1.6[a]" -map "[v]" -map "[a]" -q:v 0 -q:a 0 audiovideo_out.avi
 ffmpeg -i audiovideo.avi -filter_complex "[0:v]setpts=0.5*PTS[v];[0:a]atempo=2[a]"     -map "[v]" -map "[a]" -q:v 0 -q:a 0 audiovideo_out.avi


wyjmowanie dzwieku i obrazu (kanaly, czy tam strumienie):
 ffmpeg -i plik.avi -map 0:0 -q:v 0 plik-V.avi    # (0:0 typowo, nie zawsze)
 ffmpeg -i plik.avi -map 0:1 -q:a 0 plik-A.wav    # (0:1 typowo, nie zawsze)
zubozony dzwiek:
 ffmpeg -i plik.avi -map 0:1 -q:a 0 -ac 1 -ar 24000 plik-A.wav

zlozenie z powrotem:
 ffmpeg -i plik-V.avi -i plik-A.wav -map 0:0 -q:v 0 -map 1:0 -q:a 0 plik-AV.avi


Proste wyciaganie audio z niepotrzebnego wideo do MP3:
 ffmpeg -i input.mpeg -ab 128k output.mp3
 for p in *.mp4 ; do ffmpeg -i $p -ac 1 wav/$p.wav ; done
 fldr="ffwav"; inext="mp4"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.$inext; do nn=`basename $plik .$inext`.wav ; echo "$plik -> $fldr/$nn ..."; ffmpeg -i $plik -ac 1 $fldr/$nn ; done


volume kanalu audio:
detekcja:
 ffmpeg -i video.avi -af "volumedetect" -f null /dev/null
 for p in *.mp4 ; do echo -en "$p\t" ; ffmpeg -i $p -af "volumedetect" -f null /dev/null 2>&1 |  grep max_volume ; done
sterowanie:
 ffmpeg -i tmp03.avi -af "volume=1.7" -qscale 0 tmp03_louder.avi


crop:
 ffmpeg -i input.avi -filter:v "crop=1280:1024:x:y" -q:v 0 -q:a 0 output.avi
lektura 1: http://video.stackexchange.com/questions/4563/how-can-i-crop-a-video-with-ffmpeg
 1280:    the width of the output rectangle,
 1024:    the height,
 x and y: the top left corner
lektura 2: http://www.renevolution.com/understanding-ffmpeg-part-iii-cropping/
           http://www.ffmpeg.org/ffmpeg-filters.html#crop



concating:
 ffmpeg -i "concat:input1.mpeg|input2.mpeg|input3.mpeg" -c copy output.mpg
albo:
 ffmpeg -f concat -i concatlist -qscale 0 -c copy 321_x8.avi
  concatlist:
   file 321a.avi
   file 321b_x8.avi
   file 321c.avi

join AVIs with damaged index and to MP4:
 cat DSCI00* > output.avi
 mencoder -mc 0 -noskip -oac copy -ovc copy output.avi -o outfile.avi
 HandBrakeCLI -Z Android -i outfile.avi -o DSCI00.mp4
 rm output.avi outfile.avi

kombajn do MPEG:
 mpgtx [http://mpgtx.sourceforge.net/#Examples]
 np concat: mpgtx -j input1.mpg input2.mpg -o output.mpg


get resolution:
 ffprobe INPUT 2>&1 | egrep "Stream.*Video" | egrep -o "[[:digit:]]{3,4}x[[:digit:]]{3,4}"

jedynie wyswietl resolution w folderze:
 for plik in *.AVI; do echo -en "$plik:\t"; ffprobe $plik 2>&1 | egrep "Stream.*Video" | egrep -o "[[:digit:]]{3,4}x[[:digit:]]{3,4}"; done | column -t


rotate (90, 270):
 ffmpeg -i INPUT -vf "transpose=1" -qscale 0 OUT90
 ffmpeg -i INPUT -vf "transpose=2" -qscale 0 OUT270


batch repare AVIs (pilot czasem):
 for plik in `ls *.avi`; do mencoder -mc 0 -noskip -oac copy -ovc copy $plik -o m_$plik; done


A batch ts->mp4 transcoding command for convenience:
HandBrake:
 for plik in `ls *.avi`; do HandBrakeCLI -Z Android -i $plik -o $plik.mp4; done
 for plik in `ls *.avi`; do HandBrakeCLI -i $plik -o $plik-n.mp4; done
ffmpeg:
 for plik in `ls *.avi`; do ffmpeg -i $plik -map 0 -acodec libfaac -vcodec h264 -f mp4 $plik-ffmpeg.mp4; done


Ultimate nice mp4 coder:
 ffmpeg -i INPUT -c:v libx264 -preset veryfast -crf 26 -c:a aac -b:a 128k -ar 44100 -ac 2 -sn -strict experimental OUTPUT
 ffmpeg -i INPUT -c:v libx264 -preset veryfast -crf 28 -c:a aac -b:a  64k -ar 24000 -ac 1 -sn -strict experimental OUTPUT
 for plik in INPUT; do ffmpeg -i $plik                  -c:v libx264 -preset veryfast -crf 28 -c:a aac -b:a 64k -ar 44100 -ac 1 -sn -strict experimental $plik-ffmpeg.mp4; done
 for plik in INPUT; do ffmpeg -i $plik -vf scale=640:-1 -c:v libx264 -preset veryfast -crf 28 -c:a aac -b:a 64k -ar 44100 -ac 1 -sn -strict experimental $plik-ffmpeg.mp4; done        # [https://trac.ffmpeg.org/wiki/Scaling%20(resizing)%20with%20ffmpeg]
 fldr="ffmpeg"; [ ! -d $fldr ] && mkdir $fldr; for plik in INPUT; do ffmpeg -y -i $plik -c:v libx264 -preset veryfast -crf 28 -c:a aac -b:a 64k -ar 44100 -ac 1 -sn -strict experimental $fldr/$plik-crf28.mp4; done


Proste rozjasnienie MPG:
 ffmpeg -y -i input.mpg -vf "mp=eq2=1.0:2:0.5" -map 0 -qscale 0 output.mpg
 ffmpeg -y -i input.jpg -vf "lutrgb='r=1.5*val:g=1.5*val:b=1.5*val'" -map 0 -qscale 0 output.jpg
 fldr="ffmpeg"; [ ! -d $fldr ] && mkdir $fldr; for plik in INPUT; do ffmpeg -y -i $plik -vf "mp=eq2=1.0:2:0.5" -map 0 -qscale 0 $fldr/$plik; done
 fldr="ffmpeg"; [ ! -d $fldr ] && mkdir $fldr; for plik in INPUT; do ffmpeg -y -i $plik -vf "lutrgb='r=1.5*val:g=1.5*val:b=1.5*val'" -map 0 -qscale 0 $fldr/$plik; done
 fldr="ffmpeg"; [ ! -d $fldr ] && mkdir $fldr; for plik in INPUT; do ffmpeg -y -i $plik -vf "lutyuv=y=val*1.5" -map 0 -qscale 0 $fldr/$plik; done


WAV -> OGG (+Q):
 ffmpeg -loglevel error -i plik.wav -c:a libvorbis -qscale:a 1 plik_q1.ogg
(+batch):
 fldr="ffogg"; inext="wav"; Q="3" ; [ ! -d $fldr ] && mkdir $fldr; for plik in *.$inext; do nn=`basename $plik .$inext`.ogg ; echo "$plik -> $fldr/$nn ..."; ffmpeg -loglevel error -i $plik -c:a libvorbis -qscale:a $Q $fldr/$nn ; done

inext -> WAV (batch):
 fldr="ffwav"; inext="mp4"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.$inext; do nn=`basename $plik .$inext`.wav ; echo "$plik -> $fldr/$nn ..."; ffmpeg -loglevel error -i $plik $fldr/$nn ; done
(+mono+rate):         [https://trac.ffmpeg.org/wiki/AudioChannelManipulation]
 fldr="ffwav"; inext="mp4"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.$inext; do nn=`basename $plik .$inext`.wav ; echo "$plik -> $fldr/$nn ..."; ffmpeg -loglevel error -i $plik -ar 22050 -ac 1 $fldr/$nn ; done

-> MP3 VBR:      [https://trac.ffmpeg.org/wiki/Encode/MP3]
 ffmpeg -loglevel error -i input.mp3 -codec:a libmp3lame -qscale:a 4 output-q4stereo.mp3
(+mono):         [https://trac.ffmpeg.org/wiki/AudioChannelManipulation]
 ffmpeg -loglevel error -i input.mp3 -codec:a libmp3lame -qscale:a 4 -ac 1 output-q4stereo.mp3


simple MP3 -> MP3 mono:
 fldr="ffmono"; [ ! -d $fldr ] && mkdir $fldr ; for p in *.mp3 ; do ffmpeg -loglevel error -i $p -ac 1 $fldr/$p ; done
 fldr="ffmono"; [ ! -d $fldr ] && mkdir $fldr ; for p in *.mp3 ; do ffmpeg -loglevel error -i $p -ac 1 $fldr/$p ; done && mv $fldr/* . && rmdir $fldr

more aggresive MP3 -> MP3 mono (+settings, crawling folders L1):
fldr="ffmono" &&
for f in * ; do     # assuming all are folders
  echo $f ; cd $f
  [ ! -d $fldr ] && mkdir $fldr ; for p in *.mp3 ; do ffmpeg -loglevel error -i $p -b:a 48k -ar 24000 -ac 1 $fldr/$p ; echo -n '.' ; done && mv $fldr/* . && rmdir $fldr
  echo
  cd - >/dev/null
  sleep 10
done


batch movie clips compress:
  echo ; for p in `ls` ; do echo "time ffmpeg -loglevel error -y -i \"$p\" -vf scale=960:-1                            -c:v libx264 -preset veryfast -crf 28 -c:a aac -b:a 128k -ar 44100 -ac 2 -sn -strict experimental \"ffmpeg/$p-crf28.mp4\" && sleep 20 &&" ; done ; echo
  echo ; for p in `ls` ; do echo "time ffmpeg -loglevel error -y -i \"$p\" -vf scale=`jwffgetvideoresolution \"$p\" 720` -c:v libx264 -preset veryfast -crf 28 -c:a aac -b:a 128k -ar 44100 -ac 2 -sn -strict experimental \"ffmpeg/$p-crf28.mp4\" && sleep 20 &&" ; done ; echo
  echo ; for p in `ls` ; do echo "time ffmpeg -loglevel error -y -i \"$p\"                                             -c:v libx264 -preset veryfast -crf 28 -c:a aac -b:a 128k -ar 44100 -ac 2 -sn -strict experimental \"ffmpeg/$p-crf28.mp4\" && sleep 20 &&" ; done ; echo

cisza (wykryj, usun):
 http://www.ffmpeg.org/ffmpeg-filters.html#toc-silencedetect
 http://www.ffmpeg.org/ffmpeg-filters.html#toc-silenceremove

szum (redukuj):
 http://superuser.com/questions/733061/reduce-background-noise-and-optimize-the-speech-from-an-audio-clip-using-ffmpeg
 http://www.zoharbabin.com/how-to-do-noise-reduction-using-ffmpeg-and-sox/

EOF
}


jwffcutframe()
{

    if [ $# -ne 1 ]; then
cat 1>&2 <<EOF

 ./$FUNCNAME  clip_name

   Cuts frame from clip at 10s, 60s and 5m (if long enough).

EOF
        return 1
    fi


    local CLIP=$1

    local CMD_TEMPLATE="ffmpeg -i __INPUT__ -ss __POINT__ -t 1 -q:v 0 -r 1 -f image2 __OUTPUT__"

    local POINT1=10
    local POINT2=60
    local POINT3=300

    local _filename=$(basename -- "$CLIP")
    local CLIP_FILENAME="${_filename%.*}"

    local LEN_FRAC=`ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $CLIP`
    local LEN_S=`echo $LEN_FRAC | awk '{print int($1)}'`


    for pnt in $POINT1 $POINT2 $POINT3 ; do

        if [ $LEN_S -gt $pnt ] ; then

            echo $CMD_TEMPLATE | sed "s/__INPUT__/$CLIP/" \
                               | sed "s/__POINT__/$pnt/" \
                               | sed "s/__OUTPUT__/$CLIP_FILENAME-frame$pnt.jpg/"

        fi

    done

}

jwffcropfilter ()
{

    if [ $# -ne 4 ]; then
cat 1>&2 <<EOF


 Crop filter for ffmpeg.

 -filter:v "crop=w:h:x:y"

  w:    the width of the output rectangle,
  h:    the height of the output rectangle,
  x:    the top left corner: X
  y:    the top left corner: Y

 ./$FUNCNAME  rect_width  rect_height  topleft_x  topleft_y

EOF
        return 1
    fi


    local W=$1
    local H=$2
    local X=$3
    local Y=$4

    echo
    echo " -filter:v \"crop=$W:$H:$X:$Y\""
    echo

}


jwffblender-postencode ()
{
  if [ $# -ne 1 ]; then
    echo "  Nazwę pliczku podaj. Zakłada kontener AVI."
    return 1
  fi

  NAZWA_PLIKU=$1
  NAZWA_PLIKU_NOEXT=${NAZWA_PLIKU%.avi}

  echo

  echo "# rozdzielczosc nieruszana"

  NAZWA_PLIKU_2="$NAZWA_PLIKU_NOEXT""_02.avi"
  NAZWA_PLIKU_3="$NAZWA_PLIKU_NOEXT""_03.avi"
  NAZWA_PLIKU_4="$NAZWA_PLIKU_NOEXT""_04.avi"
  NAZWA_PLIKU_4MP4="$NAZWA_PLIKU_NOEXT""_04-crf.mp4"

  echo 

  echo "ffmpeg -i $NAZWA_PLIKU    -q:v 0 -q:a 0           $NAZWA_PLIKU_2"
  echo "ffmpeg -i $NAZWA_PLIKU_2 -q:v 0 -q:a 0           $NAZWA_PLIKU_3"
  echo "ffmpeg -i $NAZWA_PLIKU_3 -q:v 4 -q:a 0 -ar 44100 $NAZWA_PLIKU_4"
  echo "ffmpeg -i $NAZWA_PLIKU_3 -c:v libx264 -preset veryfast -crf 26 -c:a aac -b:a 128k -ar 44100 -ac 2 -sn -strict experimental $NAZWA_PLIKU_4MP4"
  echo "rm $NAZWA_PLIKU_2"
  echo "rm $NAZWA_PLIKU_3"
  echo 


  echo "# rozdzielczosc -> 960"

  NAZWA_PLIKU_NOEXT_960="$NAZWA_PLIKU_NOEXT""_960"

  NAZWA_PLIKU_960_2="$NAZWA_PLIKU_NOEXT_960""_02.avi"
  NAZWA_PLIKU_960_3="$NAZWA_PLIKU_NOEXT_960""_03.avi"
  NAZWA_PLIKU_960_4="$NAZWA_PLIKU_NOEXT_960""_04.avi"

  echo "ffmpeg -i $NAZWA_PLIKU                         -q:v 0 -q:a 0           $NAZWA_PLIKU_960_2"
  echo "ffmpeg -i $NAZWA_PLIKU_960_2                  -q:v 0 -q:a 0           $NAZWA_PLIKU_960_3"
  echo "ffmpeg -i $NAZWA_PLIKU_960_3 -vf scale=960:-1 -q:v 4 -q:a 0 -ar 44100 $NAZWA_PLIKU_960_4"
  echo "rm $NAZWA_PLIKU_960_2"
  echo "rm $NAZWA_PLIKU_960_3"
  echo 
}


#--------------------------

jwffmpgrotateCW () 
{ 
  if [ $# -ne 1 ]; then
    echo "  Rotating INPLACE by 90deg"
    echo "  ${FUNCNAME[0]} plikIN.mpg" 1>&2
    return
  fi
  IN=$1
  OUT="temp_.$$.mpg"
  echo ffmpeg -i $IN -vf "transpose=1" -qscale 0 $OUT
  echo
  sleep 1
  ffmpeg -i $IN -vf "transpose=1" -qscale 0 $OUT
  mv -v $OUT $IN
}

jwffmpgrotateCCW () 
{ 
  if [ $# -ne 1 ]; then
    echo "  Rotating INPLACE by 90deg"
    echo "  ${FUNCNAME[0]} plikIN.mpg" 1>&2
    return
  fi
  IN=$1
  OUT="temp_.$$.mpg"
  echo ffmpeg -i $IN -vf "transpose=2" -qscale 0 $OUT
  echo
  sleep 1
  ffmpeg -i $IN -vf "transpose=2" -qscale 0 $OUT
  mv -v $OUT $IN
}


jwffcropclip ()
{
  if [ $# -ne 3 ]; then
    echo
    echo " *** $0 KLIP OD DO"
    echo "     (w miejscu!)"
    echo
    return 1
  fi

  local PLIK=$1
  local OD=$2
  local DO=$3
  local EXT="${PLIK##*.}"

  local TEMP="temp-$$.$EXT"

  echo "ffmpeg -i \"$PLIK\" -ss $OD -to $DO -c:v copy -c:a copy $TEMP && mv $TEMP \"$PLIK\""
}

