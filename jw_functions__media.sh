# A collection of miscellaneous media manipulation functions


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


jwmogrify ()
{
cat 1>&2 <<'EOF'

=================== I M A G E M A G I C K =================== (notes and command templates)

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
  (photos brightening)
fldr="convert"; [ ! -d $fldr ] && mkdir $fldr; for p in *.jpg; do echo $p; convert -brightness-contrast 15x15 -quality 75% $p $fldr/$p; done
fldr="convert"; [ ! -d $fldr ] && mkdir $fldr; for p in *.jpg; do echo $p; convert -brightness-contrast 20x15 -quality 75% $p $fldr/$p; done
  (rotating)
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
 horizontal scrolling - an example:
  for i in `seq 1280 3 1780` ; do convert input.jpg -crop 1280x720+$i+1120 out_$i.png ; done
  ffmpeg -i out_%3d.png -r 30 -qscale 0 output.avi

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
        sox $plik -C -$CMPR_FAC.01 $fldr/$plik
    done
    mv $fldr/* . ; rmdir $fldr
    echo
    jwffbitrateEXT mp3

}

alias jwcompressmp3sox='jwcompressmp3sox_CMPR_FAC 4'
alias jwcompressmp3sox5='jwcompressmp3sox_CMPR_FAC 5'
alias jwcompressmp3sox6='jwcompressmp3sox_CMPR_FAC 6'
alias jwcompressmp3sox7='jwcompressmp3sox_CMPR_FAC 7'

jwcompressjpg65 () 
{

    if [ $# -ne 0 ]
    then
cat 1>&2 <<EOF

$FUNCNAME

    A convenience function for batch jpg files compression. Does so by decreasing file quality.
    Processes all jpg files at the current location.

EOF
        return 1
    fi

    for p in *.jpg; do echo $p; mogrify -strip -interlace Plane -quality 65% $p; done
    
}

