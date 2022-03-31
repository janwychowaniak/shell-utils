# A collection of miscellaneous media manipulation functions


# --------------------------------------------------------------------------------------


jwsox ()
{
cat 1>&2 <<'EOF'

=================== S O X =================== (notes and command templates)

MP3: mixdown to mono:
 sox input.mp3 output.mp3 channels 1

MP3: custom kbps settings:
 sox input.mp3 -C 40.2 output-40.mp3

MP3: doubling the tempo, optimized for speech:
 sox input.mp3 output-x2.mp3 tempo -s 2

MP3: mixdown to mono + doubling the tempo optimized for speech + custom kbps settings:
 sox input.mp3 -C 40.2 output.mp3 channels 1 tempo -s 2

MP3: the above batch'd:
 fldr="sox"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.mp3; do echo "$plik -> $fldr ..."; sox $plik -C 56.2 $fldr/$plik channels 1 tempo -s 2; done
 fldr="sox"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.mp3; do echo "$plik -> $fldr ..."; sox $plik -C -5.01 $fldr/$plik ; done
 fldr="sox"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.mp3; do echo "$plik -> $fldr ..."; sox $plik -C -4.01 $fldr/$plik ; done ; mv $fldr/* . ; rmdir $fldr
 fldr="sox"; inext="wav"; [ ! -d $fldr ] && mkdir $fldr; for plik in *.$inext; do nn=`basename $plik .$inext`.mp3 ; echo "$plik -> $fldr/$nn ..."; sox $plik -C -4.01 $fldr/$nn ; done


OGG: custom quality settings:
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

=================== Y O U T U B E - D L =================== (notes and command templates)
[https://github.com/ytdl-org/youtube-dl]

youtube-dl -t -f worst --extract-audio --audio-format wav
youtube-dl -f 140 --match-title felieton --playlist-start 170 https://www.youtube.com/user/egida1/videos
youtube-dl -f "18/43"   https://www.youtube.com/watch?v=FILMIK_ID
youtube-dl -f "171/140" https://www.youtube.com/playlist?list=LISTA_ID
youtube-dl -f "171/140" --datebefore 20151231 https://www.youtube.com/playlist?list=LISTA_ID

output title templates:
 no output formatting                                                Grupa Operacyjna - 'Świr'-n9O5AcnVSIo.webm
 -o "%(autonumber)s_-_%(title)s.%(ext)s"                             00001_-_Grupa Operacyjna - 'Świr'.webm
 -o "%(autonumber)s_-_%(title)s-%(id)s.%(ext)s"                      00001_-_Grupa Operacyjna - 'Świr'-n9O5AcnVSIo.webm
 -o "%(autonumber)s_-_%(title)s-%(id)s.%(ext)s" --autonumber-size 2  01_-_Grupa Operacyjna - 'Świr'-n9O5AcnVSIo.webm
 -o "%(autonumber)s_-_%(title)s.%(ext)s" --autonumber-size 2         01_-_Grupa Operacyjna - 'Świr'.webm
 -o "%(upload_date)s-%(title)s-%(id)s.%(ext)s"                       20150720-Jestem buntownikiem _ Jacek WIOSNA Stryczek-KCsG3G4SMrc.webm

transcoder selection (ffmpeg):
 --prefer-ffmpeg --ffmpeg-location $(which ffmpeg)

downloads the entire playlist, starting with the oldest:
 youtube-dl -f 171 -o "%(autonumber)s_-_%(title)s-%(id)s.%(ext)s" --autonumber-size 3 --playlist-reverse  "https://www.youtube.com/channel/KANAL_ID/videos"

downloads a sub-playlist:
 youtube-dl -f 140 --playlist-start 1 --playlist-end 18 -o "%(autonumber)s_-_%(title)s.%(ext)s" --autonumber-size 2  https://www.youtube.com/playlist?list=LISTA_ID

get filename with date (simulate download, no actual download):
 youtube-dl -o "%(upload_date)s-%(title)s-%(id)s.%(ext)s" --get-filename  https://www.youtube.com/user/KANAL_ID/videos

download full video or audio only, output format starts with date, after given date:
 youtube-dl -f "18/43"   -o "%(upload_date)s-%(title)s-%(id)s.%(ext)s" --dateafter 20151231  https://www.youtube.com/playlist?list=LISTA_ID
 youtube-dl -f "171/140" -o "%(upload_date)s-%(title)s-%(id)s.%(ext)s" --dateafter 20151231  https://www.youtube.com/playlist?list=LISTA_ID

download entire playlist, output format starts with date, with custom quality setting and without (i.e. best):
 youtube-dl -f "18/43" -o "%(upload_date)s-%(title)s-%(id)s.%(ext)s"  https://www.youtube.com/playlist?list=LISTA_ID
 youtube-dl            -o "%(upload_date)s-%(title)s-%(id)s.%(ext)s"  https://www.youtube.com/playlist?list=LISTA_ID

EOF
}


jwgetimageresolution ()
{
    if [[ $# -lt 1 ]] || [[ $# -gt 2 ]] ; then
        echo
        echo "$FUNCNAME EXT [min-mpix]"
        echo
        echo "    A simple function for telling the dimensions (resolution) of all the image files"
        echo "    with a given extension present at the current location."
        echo "    The optional parameter specifies to show only files larger than a given megapixel size."
        echo
        echo "    1984x1984 == 2.95 mpix"
        echo "    2592x2592 == 5.03 mpix"
        echo
        return 1
    fi

    local EXT=$1

    if [ $# -eq 2 ]; then
        MINMPIX=$2 # TODO
    fi

    for p in *."$EXT"
    do
        exift_size=$(exiftool "$p" | grep "Image Size" | awk '{print $4}' | grep -v ':' )
        exift_w=$(echo "$exift_size" | tr "x" " " | awk '{print $1}')
        exift_h=$(echo "$exift_size" | tr "x" " " | awk '{print $2}')
        mpix=$(echo "scale=2 ; $exift_w * $exift_h / 1000000" | bc)

        if [ $# -eq 1 ]; then
            echo -e "$p\\t: $exift_w*$exift_h  [$mpix mpix]"
        elif [ $# -eq 2 ]; then
            if [ $(echo $mpix'>'$MINMPIX | bc -l) -eq 1 ] ; then
                echo -e "$p\\t: $exift_w*$exift_h  [$mpix mpix]"
            fi
        fi
    done
}


jwcompressmp3sox_CMPR_FAC ()
{
    if [ $# -ne 1 ]
    then
cat 1>&2 <<EOF

$FUNCNAME COMPR_FACTOR

    A function for batch MP3 files compression. Does so by decreasing file quality to a level determined by COMPR_FACTOR.
    Processes all MP3 files at the current location.

EOF
        return 1
    fi

    local CMPR_FAC=$1

cat 1>&2 <<EOF # The actual command used

  fldr="sox"; [ ! -d \$fldr ] && mkdir \$fldr; for plik in *.mp3; do echo "\$plik -> \$fldr ..."; sox \$plik -C -$CMPR_FAC.01 \$fldr/\$plik ; done ; mv \$fldr/* . ; rmdir \$fldr

EOF

    fldr="sox"; [ ! -d $fldr ] && mkdir $fldr
    for plik in *.mp3
    do
        echo "$plik -> $fldr ..."
        sox "$plik" -C -$CMPR_FAC.01 "$fldr/$plik"
    done
    mv $fldr/* . ; rmdir $fldr
    echo
    jwffbitrateEXT mp3
}

alias jwcompressmp3sox='jwcompressmp3sox_CMPR_FAC 4'
alias jwcompressmp3sox5='jwcompressmp3sox_CMPR_FAC 5'
alias jwcompressmp3sox6='jwcompressmp3sox_CMPR_FAC 6'
alias jwcompressmp3sox7='jwcompressmp3sox_CMPR_FAC 7'

