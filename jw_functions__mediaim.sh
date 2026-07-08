# A collection of miscellaneous image manipulation / inspection functions
# Underlying is the ImageMagick toolkit (+ exiftool for image probing)

# --------------------------------------------------------------------------------------


jwimmogrify ()
{
cat 1>&2 <<'EOF'

=================== I M A G E M A G I C K =================== (notes and command templates)

> PNG -quality is NOT lossy: the value encodes zlib_level*10 + filter.
>   tens digit  = zlib compression level 0-9   (9 = smallest file, slowest)
>   units digit = PNG filter (5 = adaptive, 0 = none)
>   -quality 0  = library default (NOT level 0)
> PNG is lossless, so -quality only trades file size / CPU, never fidelity.
> (Contrast JPEG, where -quality IS a real quality/size knob, ~1-100.)


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


jwimcompressjpg65 () 
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

    for p in *.jpg; do echo "$p"; mogrify -strip -interlace Plane -quality 65% "$p"; done
}


jwimconvertbrightnesscontrast ()
{
    if [ $# -ne 1 ]; then
cat 1>&2 <<EOF

$FUNCNAME SRCFILE

    A couple of versions of the input file specified by SRCFILE are generated,
    varying in the levels of brightness and contrast.

EOF
        return 1
    fi

    local SRCFILE=$1

    local extension="${SRCFILE##*.}"
    local filename_noext="${SRCFILE%.*}"

    echo "filename_noext : $filename_noext"
    echo "extension      : $extension"

    convert -brightness-contrast  0x0  "$SRCFILE" /tmp/"${filename_noext}__00x00.${extension}" && echo " -> /tmp/${filename_noext}__00x00.${extension}"
    convert -brightness-contrast 10x10 "$SRCFILE" /tmp/"${filename_noext}__10x10.${extension}" && echo " -> /tmp/${filename_noext}__10x10.${extension}"
    convert -brightness-contrast 20x20 "$SRCFILE" /tmp/"${filename_noext}__20x20.${extension}" && echo " -> /tmp/${filename_noext}__20x20.${extension}"
    convert -brightness-contrast 30x30 "$SRCFILE" /tmp/"${filename_noext}__30x30.${extension}" && echo " -> /tmp/${filename_noext}__30x30.${extension}"
    convert -brightness-contrast 40x40 "$SRCFILE" /tmp/"${filename_noext}__40x40.${extension}" && echo " -> /tmp/${filename_noext}__40x40.${extension}"
    convert -brightness-contrast 50x50 "$SRCFILE" /tmp/"${filename_noext}__50x50.${extension}" && echo " -> /tmp/${filename_noext}__50x50.${extension}"
    convert -brightness-contrast 60x60 "$SRCFILE" /tmp/"${filename_noext}__60x60.${extension}" && echo " -> /tmp/${filename_noext}__60x60.${extension}"
    convert -brightness-contrast 70x70 "$SRCFILE" /tmp/"${filename_noext}__70x70.${extension}" && echo " -> /tmp/${filename_noext}__70x70.${extension}"
    convert -brightness-contrast 80x80 "$SRCFILE" /tmp/"${filename_noext}__80x80.${extension}" && echo " -> /tmp/${filename_noext}__80x80.${extension}"
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
