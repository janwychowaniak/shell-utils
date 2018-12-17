jwsox ()
{
cat 1>&2 <<'EOF'

=================== S O X ===================

MP3: mix to mono:
 sox input.mp3 output.mp3 channels 1

MP3: kodowanie z okreslieniem kbps:
 sox input.mp3 -C 40.2 output-40.mp3

MP3: podniesienie tempa x2 z optymalizacja pod mowe:
 sox input.mp3 output-x2.mp3 tempo -s 2

MP3: mix to mono, podniesienie tempa x2 z optymalizacja pod mowe, kodowanie do MP3 z okreslieniem kbps:
 sox input.mp3 -C 40.2 output.mp3 channels 1 tempo -s 2

MP3: j/w batch'd:
 fldr="sox"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.mp3; do echo "$plik -> $fldr ..."; sox $plik -C 56.2 $fldr/$plik channels 1 tempo -s 2; done
 fldr="sox"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.mp3; do echo "$plik -> $fldr ..."; sox $plik -C -5.01 $fldr/$plik ; done
 fldr="sox"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.mp3; do echo "$plik -> $fldr ..."; sox $plik -C -4.01 $fldr/$plik ; done ; mv $fldr/* . ; rmdir $fldr
 fldr="sox"; inext="wav"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.$inext; do nn=`basename $plik .$inext`.mp3 ; echo "$plik -> $fldr/$nn ..."; sox $plik -C -4.01 $fldr/$nn ; done


OGG: kodowanie z okreslieniem jakosci:
 sox INPUT.cos -V2 -C 3 OUTPUT.ogg
 fldr="sox"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.wav; do echo "$plik -> $fldr/..."; sox $plik -V2 -C -1 $fldr/$plik.ogg tempo -s 2 ; done
 fldr="sox"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.wav; do echo "$plik -> $fldr/..."; sox $plik -V2 -C -1 $fldr/$plik.ogg channels 1 tempo -s 2 ; done
 fldr="sox"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.wav; do echo "$plik -> $fldr/..."; sox $plik -V2 -C -1 $fldr/$plik.ogg channels 1 tempo -s 2 rate 22050 ; done

 fldr="sox"; inext="mp3"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.$inext; do nn=`basename $plik .$inext`.ogg ; echo "$plik -> $fldr/$nn ..."; sox $plik -V2 -C -1 $fldr/$nn channels 1 tempo -s 1.6 rate 22050 ; done

 +silence: (http://digitalcardboard.com/blog/2009/08/25/the-sox-of-silence/)
  "sox in.wav out7.wav silence -l 1 0.01 -40d -1 0.5 -40d "

  fldr="sox"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.wav; do echo "$plik -> $fldr/..."; sox $plik -V2 -C -1 $fldr/$plik.ogg silence -l 1 0.01 -40d -1 0.5 -40d tempo -s 2 ; done
  fldr="sox"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.wav; do echo "$plik -> $fldr/..."; sox $plik -V2 -C -1 $fldr/$plik.ogg silence -l 1 0.01 -40d -1 0.5 -40d channels 1 tempo -s 2 ; done
  fldr="sox"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.wav; do echo "$plik -> $fldr/..."; sox $plik -V2 -C -1 $fldr/$plik.ogg silence -l 1 0.01 -40d -1 0.5 -40d channels 1 tempo -s 2 rate 22050 ; done

  fldr="sox"; inext="mp3"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.$inext; do nn=`basename $plik .$inext`.ogg ; echo "$plik -> $fldr/$nn ..."; sox $plik -V2 -C -1 $fldr/$nn silence -l 1 0.01 -40d -1 0.5 -40d channels 1 tempo -s 1.6 rate 22050 ; done


EOF
}


jwyoutubedl ()
{
cat 1>&2 <<'EOF'

https://github.com/rg3/youtube-dl/blob/master/README.md

=================== y o u t u b e - d l ===================

youtube-dl -t -f worst --extract-audio --audio-format wav
youtube-dl -f 140 --match-title felieton --playlist-start 170 https://www.youtube.com/user/egida1/videos
youtube-dl -f "18/43"   https://www.youtube.com/watch?v=FILMIK_ID
youtube-dl -f "171/140" https://www.youtube.com/playlist?list=LISTA_ID
youtube-dl -f "171/140" --datebefore 20151231 https://www.youtube.com/playlist?list=LISTA_ID

output title templates:
 bez -o lub -o "%(title)s-%(id)s.%(ext)s"                            Grupa Operacyjna - 'Świr'-n9O5AcnVSIo.webm
 -o "%(autonumber)s_-_%(title)s.%(ext)s"                             00001_-_Grupa Operacyjna - 'Świr'.webm
 -o "%(autonumber)s_-_%(title)s-%(id)s.%(ext)s"                      00001_-_Grupa Operacyjna - 'Świr'-n9O5AcnVSIo.webm
 -o "%(autonumber)s_-_%(title)s-%(id)s.%(ext)s" --autonumber-size 2  01_-_Grupa Operacyjna - 'Świr'-n9O5AcnVSIo.webm
 -o "%(autonumber)s_-_%(title)s.%(ext)s" --autonumber-size 2         01_-_Grupa Operacyjna - 'Świr'.webm
 -o "%(upload_date)s-%(title)s-%(id)s.%(ext)s"                       20150720-Jestem buntownikiem _ Jacek WIOSNA Stryczek-KCsG3G4SMrc.webm

transcoder select (ffmpeg):
 --prefer-ffmpeg --ffmpeg-location $(which ffmpeg)

zasys calej listy od najstarszych:
 youtube-dl -f 171 -o "%(autonumber)s_-_%(title)s-%(id)s.%(ext)s" --autonumber-size 3 --playlist-reverse  "https://www.youtube.com/channel/KANAL_ID/videos"

zasys fragmentu listy z muzyka:
 youtube-dl -f 140 --playlist-start 1 --playlist-end 18 -o "%(autonumber)s_-_%(title)s.%(ext)s" --autonumber-size 2  https://www.youtube.com/playlist?list=LISTA_ID

get-filename z data (symulacja) i -f pod zasys umiarkowanego video:
 youtube-dl -f "18/43" -o "%(upload_date)s-%(title)s-%(id)s.%(ext)s" --get-filename  https://www.youtube.com/user/KANAL_ID/videos

zasys video z upload-date na poczatku (z kontrola jakosci i bez (i.e. best)):
 youtube-dl -f "18/43" -o "%(upload_date)s-%(title)s-%(id)s.%(ext)s"  https://www.youtube.com/playlist?list=LISTA_ID
 youtube-dl            -o "%(upload_date)s-%(title)s-%(id)s.%(ext)s"  https://www.youtube.com/playlist?list=LISTA_ID

zasys video/audio z upload-date na poczatku po danej dacie:
 youtube-dl -f "18/43"   -o "%(upload_date)s-%(title)s-%(id)s.%(ext)s" --dateafter 20151231  https://www.youtube.com/playlist?list=LISTA_ID
 youtube-dl -f "171/140" -o "%(upload_date)s-%(title)s-%(id)s.%(ext)s" --dateafter 20151231  https://www.youtube.com/playlist?list=LISTA_ID

EOF
}


jwbitrateEXT() {
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

alias jwbitrate='jwbitrateEXT mp3'
alias jwbitrate_mp3='jwbitrateEXT mp3'
alias jwbitrate_wav='jwbitrateEXT wav'
alias jwbitrate_ogg='jwbitrateEXT ogg'
alias jwbitrate_mp4='jwbitrateEXT mp4'
alias jwbitrate_m4a='jwbitrateEXT m4a'
alias jwbitrate_webm='jwbitrateEXT webm'


jwmeanbitrateEXT () 
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

alias jwmeanbitrate="jwmeanbitrateEXT mp3"


jwaudioparamsEXT() {
  EXT=$1
  leadingws=80;

  for p in *.$EXT ; do

    ffpro_outp=$(ffprobe "$p" 2>&1 | grep Audio)

    printf "%$(echo $leadingws)s" "$p  ->"
    echo " "$ffpro_outp

  done
}

alias jwaudioparams='jwaudioparamsEXT mp3'
alias jwaudioparams_mp3='jwaudioparamsEXT mp3'
alias jwaudioparams_wav='jwaudioparamsEXT wav'
alias jwaudioparams_ogg='jwaudioparamsEXT ogg'
alias jwaudioparams_mp4='jwaudioparamsEXT mp4'
alias jwaudioparams_avi='jwaudioparamsEXT avi'
alias jwaudioparams_m4a='jwaudioparamsEXT m4a'
alias jwaudioparams_webm='jwaudioparamsEXT webm'


jwvideoparamsEXT() {
  EXT=$1
  leadingws=80;

  for p in *.$EXT ; do

    ffpro_outp=$(ffprobe "$p" 2>&1 | grep Video)

    printf "%$(echo $leadingws)s" "$p  ->"
    echo " "$ffpro_outp

  done
}

alias jwvideoparams_wav='jwvideoparamsEXT wav'
alias jwvideoparams_ogg='jwvideoparamsEXT ogg'
alias jwvideoparams_mp4='jwvideoparamsEXT mp4'
alias jwvideoparams_avi='jwvideoparamsEXT avi'


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

jwffmpeg-rozne ()
{
cat <<'EOF'

MP4 -> AVI z kontrola jakosci:
 ffmpeg -i input.mp4 -q:v 0 -q:a 0 output.avi
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
  echo ; for p in `ls` ; do echo "time ffmpeg -loglevel error -y -i \"$p\" -vf scale=`jwgetvideoresolution \"$p\" 720` -c:v libx264 -preset veryfast -crf 28 -c:a aac -b:a 128k -ar 44100 -ac 2 -sn -strict experimental \"ffmpeg/$p-crf28.mp4\" && sleep 20 &&" ; done ; echo
  echo ; for p in `ls` ; do echo "time ffmpeg -loglevel error -y -i \"$p\"                                             -c:v libx264 -preset veryfast -crf 28 -c:a aac -b:a 128k -ar 44100 -ac 2 -sn -strict experimental \"ffmpeg/$p-crf28.mp4\" && sleep 20 &&" ; done ; echo

cisza (wykryj, usun):
 http://www.ffmpeg.org/ffmpeg-filters.html#toc-silencedetect
 http://www.ffmpeg.org/ffmpeg-filters.html#toc-silenceremove

szum (redukuj):
 http://superuser.com/questions/733061/reduce-background-noise-and-optimize-the-speech-from-an-audio-clip-using-ffmpeg
 http://www.zoharbabin.com/how-to-do-noise-reduction-using-ffmpeg-and-sox/

EOF
}

jwblender-encode ()
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


jwgetvideoresolution() 
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

jwrozdzialki ()
{
  for e in `ls` ; do echo -en "$e " ; ffprobe $e 2>&1 | grep -o '[0-9]\{3,4\}x[0-9]\{3,4\}' ; done
}


jwmogrify ()
{
cat 1>&2 <<'EOF'
                                              -quality XX%   PNG    vs      
-quality XX% PNG:                             -quality XX% ->JPG:      
-------------------------------------------------------------------------------
 768   convert-qual-90                        160   convert-qual-JPG-01
 784   convert-qual-80                        160   convert-qual-JPG-02
 820   convert-qual-70                        172   convert-qual-JPG-03
 836   convert-qual-60                        192   convert-qual-JPG-04
 920   convert-qual-50                        196   convert-qual-JPG-05
 920   convert-qual-91                        212   convert-qual-JPG-06
 928   convert-qual-95                        228   convert-qual-JPG-07
 928   convert-qual-96                        244   convert-qual-JPG-08
 928   convert-qual-97                        260   convert-qual-JPG-09
 928   convert-qual-98                        280   convert-qual-JPG-10
 928   convert-qual-99                        284   convert-qual-JPG-11
 940   convert-qual-94                        312   convert-qual-JPG-12
 944   convert-qual-92                        328   convert-qual-JPG-13
 956   convert-qual-81                        344   convert-qual-JPG-14
 956   convert-qual-85                        352   convert-qual-JPG-15
 956   convert-qual-86                        360   convert-qual-JPG-16
 956   convert-qual-87                        368   convert-qual-JPG-17
 956   convert-qual-88                        380   convert-qual-JPG-18
 956   convert-qual-89                        396   convert-qual-JPG-19
 964   convert-qual-84                        400   convert-qual-JPG-20
 968   convert-qual-00                        412   convert-qual-JPG-21
 968   convert-qual-65                        432   convert-qual-JPG-22
 968   convert-qual-66                        440   convert-qual-JPG-23
 968   convert-qual-67                        448   convert-qual-JPG-24
 968   convert-qual-68                        452   convert-qual-JPG-25
 968   convert-qual-69                        456   convert-qual-JPG-26
 968   convert-qual-75                        464   convert-qual-JPG-27
 968   convert-qual-76                        468   convert-qual-JPG-28
 968   convert-qual-77                        472   convert-qual-JPG-29
 968   convert-qual-78                        480   convert-qual-JPG-30
 968   convert-qual-79                        500   convert-qual-JPG-31
 968   convert-qual-82                        508   convert-qual-JPG-32
 980   convert-qual-40                        520   convert-qual-JPG-33
 980   convert-qual-45                        528   convert-qual-JPG-34
 980   convert-qual-71                        532   convert-qual-JPG-35
 980   convert-qual-72                        552   convert-qual-JPG-36
 980   convert-qual-74                        552   convert-qual-JPG-37
 984   convert-qual-61                        560   convert-qual-JPG-38
 984   convert-qual-62                        564   convert-qual-JPG-39
 984   convert-qual-64                        568   convert-qual-JPG-40
1004   convert-qual-55                        576   convert-qual-JPG-41
1004   convert-qual-56                        580   convert-qual-JPG-42
1004   convert-qual-57                        580   convert-qual-JPG-43
1004   convert-qual-58                        592   convert-qual-JPG-44
1004   convert-qual-59                        600   convert-qual-JPG-45
1008   convert-qual-52                        612   convert-qual-JPG-46
1016   convert-qual-42                        620   convert-qual-JPG-47
1016   convert-qual-46                        628   convert-qual-JPG-48
1016   convert-qual-47                        632   convert-qual-JPG-49
1016   convert-qual-48                        632   convert-qual-JPG-50
1016   convert-qual-49                        640   convert-qual-JPG-51
1016   convert-qual-54                        656   convert-qual-JPG-52
1020   convert-qual-30                        660   convert-qual-JPG-53
1020   convert-qual-35                        668   convert-qual-JPG-54
1032   convert-qual-44                        672   convert-qual-JPG-55
1048   convert-qual-51                        680   convert-qual-JPG-56
1084   convert-qual-20                        692   convert-qual-JPG-57
1084   convert-qual-25                        696   convert-qual-JPG-58
1084   convert-qual-41                        700   convert-qual-JPG-59
1112   convert-qual-36                        704   convert-qual-JPG-60
1112   convert-qual-37                        716   convert-qual-JPG-61
1112   convert-qual-38                        720   convert-qual-JPG-62
1112   convert-qual-39                        740   convert-qual-JPG-63
1140   convert-qual-15                        748   convert-qual-JPG-64
1140   convert-qual-34                        756   convert-qual-JPG-65
1144   convert-qual-32                        768   convert-qual-90        (1st PNG!!!)
1148   convert-qual-10                        772   convert-qual-JPG-66
1148   convert-qual-26                        776   convert-qual-JPG-67
1148   convert-qual-27                        784   convert-qual-80
1148   convert-qual-28                        796   convert-qual-JPG-68
1148   convert-qual-29                        804   convert-qual-JPG-69
1152   convert-qual-31                        812   convert-qual-JPG-70
1172   convert-qual-24                        820   convert-qual-70
1180   convert-qual-16                        820   convert-qual-JPG-71
1180   convert-qual-17                        836   convert-qual-60
1180   convert-qual-18                        836   convert-qual-JPG-72
1180   convert-qual-19                        860   convert-qual-JPG-73
1192   convert-qual-22                        868   convert-qual-JPG-74
1208   convert-qual-14                        868   convert-qual-JPG-75
1216   convert-qual-12                        888   convert-qual-JPG-76
1216   convert-qual-21                        904   convert-qual-JPG-77
1236   convert-qual-93                        920   convert-qual-50
1256   convert-qual-11                        920   convert-qual-91
1260   convert-qual-83                        928   convert-qual-95
1284   convert-qual-73                        928   convert-qual-96
1292   convert-qual-63                        928   convert-qual-97
1364   convert-qual-53                        928   convert-qual-98
1388   convert-qual-43                        928   convert-qual-99
1480   convert-qual-33                        932   convert-qual-JPG-78
1504   convert-qual-23                        940   convert-qual-94
1548   convert-qual-13                        944   convert-qual-92
3768   convert-qual-06                        944   convert-qual-JPG-79
3768   convert-qual-07                        956   convert-qual-81
3768   convert-qual-08                        956   convert-qual-85
3768   convert-qual-09                        956   convert-qual-86
3800   convert-qual-04                        956   convert-qual-87
4160   convert-qual-01                        956   convert-qual-88
4660   convert-qual-02                        956   convert-qual-89
5168   convert-qual-03                        964   convert-qual-84
5644   convert-qual-05                        968   convert-qual-00
                                              968   convert-qual-65
                                              968   convert-qual-66
                                              968   convert-qual-67
                                              968   convert-qual-68
                                              968   convert-qual-69
                                              968   convert-qual-75
                                              968   convert-qual-76
                                              968   convert-qual-77
                                              968   convert-qual-78
                                              968   convert-qual-79
                                              968   convert-qual-82
                                              976   convert-qual-JPG-80
                                              980   convert-qual-40
                                              980   convert-qual-45
                                              980   convert-qual-71
                                              980   convert-qual-72
                                              980   convert-qual-74
                                              984   convert-qual-61
                                              984   convert-qual-62
                                              984   convert-qual-64
                                              996   convert-qual-JPG-81

[http://www.ou.edu/class/digitalmedia/articles/CompressionMethods_Gif_Jpeg_PNG.html]
----------------------------------------------------------------------------------

convert -strip -interlace Plane -gaussian-blur 0.05 -quality 85% source.jpg result.jpg
mogrify -strip -interlace Plane -gaussian-blur 0.05 -quality 85% *.jpg

mogrify -strip -interlace Plane -quality 75% *.jpg
mogrify -strip -interlace Plane *.jpg


for p in INPUT; do echo $p; mogrify -strip -interlace Plane -quality 75% -resize 2000x2000 $p; done
for p in INPUT; do echo $p; mogrify -strip -interlace Plane -quality 60% $p; done


JPG:
fldr="convert"; [ ! -d $fldr ] && mkdir $fldr; for p in *.jpg; do echo $p; convert -strip -interlace Plane -quality 60% $p $fldr/$p; done
fldr="convert"; [ ! -d $fldr ] && mkdir $fldr; for p in *.jpg; do echo $p; convert -strip -interlace Plane -quality 60% -resize 2000x2000 $p $fldr/$p; done
fldr="convert"; [ ! -d $fldr ] && mkdir $fldr; for p in *.jpg; do echo $p; convert -strip -interlace Plane -quality 85% -gaussian-blur 0.05 $p $fldr/$p; done
fldr="convert"; [ ! -d $fldr ] && mkdir $fldr; for p in *.jpg; do echo $p; convert -strip -interlace Plane -quality 85% -gaussian-blur 0.05 -resize 2000x2000 $p $fldr/$p; done
  (rozjasnienie fot)
fldr="convert"; [ ! -d $fldr ] && mkdir $fldr; for p in *.jpg; do echo $p; convert -brightness-contrast 15x15 -quality 75% $p $fldr/$p; done
fldr="convert"; [ ! -d $fldr ] && mkdir $fldr; for p in *.jpg; do echo $p; convert -brightness-contrast 20x15 -quality 75% $p $fldr/$p; done
  (rotacja)
fldr="convert"; [ ! -d $fldr ] && mkdir $fldr; for p in *.jpg; do echo $p; convert -strip -interlace Plane -auto-orient -quality 60% -resize 2000x2000 $p $fldr/$p; done
fldr="convert"; [ ! -d $fldr ] && mkdir $fldr; for p in *.jpg; do echo $p; convert -strip -interlace Plane -rotate 90   -quality 60% -resize 2000x2000 $p $fldr/$p; done    # (cw)
fldr="convert"; [ ! -d $fldr ] && mkdir $fldr; for p in *.jpg; do echo $p; convert -strip -interlace Plane -rotate 270  -quality 60% -resize 2000x2000 $p $fldr/$p; done    # (ccw)

PNG:
fldr="convert"; [ ! -d $fldr ] && mkdir $fldr; for p in *.png; do echo $p; convert -quality 90% $p $fldr/$p; done


PDF -> PNG:
convert -density 200 input.pdf output-%02d.png

PNG -> PDF, force A4:
convert input-00.png input-01.png -compress jpeg -resize 1240x1753 -units PixelsPerInch -density 150x150 output.pdf

crop:  [https://codeyarns.com/2014/11/15/how-to-crop-image-using-imagemagick]
  mogrify -crop WxH+X+Y foo.png
 X: 50 Y: 100 and W: 640 H:480
  mogrify -crop 640x480+50+100 foo.png
  convert IN -crop 640x480+50+100 OUT
 poziome przewijanie zdjecia - przyklad:
  for i in `seq 1280 3 1780` ; do convert input.jpg -crop 1280x720+$i+1120 out_$i.png ; done
  ffmpeg -i out_%3d.png -r 30 -qscale 0 output.avi

EOF
}

jwgetimageresolution ()
{
    if [[ $# -lt 1 ]] || [[ $# -gt 2 ]] ; then
        echo " jwgetimageresolution ext [min-mpix]"
        echo
        echo " convert: 1984x1984 -> [2.95 mpix]"
        echo " convert: 2592x2592 -> [5.03 mpix]"
        echo
        return 1
    fi

    EXT=$1

    if [ $# -eq 2 ]; then
        MINMPIX=$2
    fi

    for p in *.$EXT
    do
        exift_size=$(exiftool "$p" | grep "Image Size" | awk '{print $4}' | grep -v ':' )
        exift_w=$(echo $exift_size | tr "x" " " | awk '{print $1}')
        exift_h=$(echo $exift_size | tr "x" " " | awk '{print $2}')
        mpix=$(echo "scale=2 ; $exift_w * $exift_h / 1000000" | bc)

        if [ $# -eq 1 ]; then
            echo -e "$p\t: $exift_w*$exift_h  [$mpix mpix]"
        elif [ $# -eq 2 ]; then
            if [ $(echo $mpix'>'$MINMPIX | bc -l) -eq 1 ] ; then
                echo -e "$p\t: $exift_w*$exift_h  [$mpix mpix]"
            fi
        fi
    done
}


# -------------------------------------------

jwmp3isstereo_exiftool ()
{
  # ~~~ prints MP3 file name if stereo ~~~ #
  # usage:
  #   for p in `find . -iname '*.mp3'` ; do jwmp3isstereo_exiftool $p ; done
  # ~~~ #
  MP3FILE="$1"
  exiftool -ChannelMode "$MP3FILE" | grep -i stereo >/dev/null
  [ $? -eq 0 ] && echo "`dirname $MP3FILE` ---> `basename $MP3FILE`"
}

jwmp3isstereo_ffprobe ()
{
  # ~~~ prints MP3 file name if not mono ~~~ #
  # usage:
  #   for p in `find . -iname '*.mp3'` ; do jwmp3isstereo_ffprobe $p ; done
  # ~~~ #
  MP3FILE="$1"
  NR_CHANNELS=`ffprobe -v quiet -print_format csv -show_streams -select_streams a $MP3FILE | awk -F "," '{print $12}'`
  [ "$NR_CHANNELS" != "1" ] && echo "`dirname $MP3FILE` ---> `basename $MP3FILE`"
}


# -------------------------------------------

jwcompressmp3sox_CMPR_FAC ()
{
  CMPR_FAC=$1

cat 1>&2 <<EOF

  fldr="sox"; [ ! -d \$fldr ] && mkdir \$fldr; for plik in *.mp3; do echo "\$plik -> \$fldr ..."; sox \$plik -C -$CMPR_FAC.01 \$fldr/\$plik ; done ; mv \$fldr/* . ; rmdir \$fldr

EOF

  fldr="sox"; [ ! -d $fldr ] && mkdir $fldr
  for plik in *.mp3
  do
    echo "$plik -> $fldr ..."
    sox $plik -C -$CMPR_FAC.01 $fldr/$plik
  done
  mv $fldr/* . ; rmdir $fldr
  echo
  jwbitrateEXT mp3
}

alias jwcompressmp3sox='jwcompressmp3sox_CMPR_FAC 4'
alias jwcompressmp3sox5='jwcompressmp3sox_CMPR_FAC 5'
alias jwcompressmp3sox6='jwcompressmp3sox_CMPR_FAC 6'
alias jwcompressmp3sox7='jwcompressmp3sox_CMPR_FAC 7'

jwcompressjpg65 () 
{
    for p in *.jpg; do echo $p; mogrify -strip -interlace Plane -quality 65% $p; done
}

#--------------------------

jwmpgrotateCW () 
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

jwmpgrotateCCW () 
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


jwcropclip ()
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

