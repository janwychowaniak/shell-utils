# A collection of miscellaneous media manipulation functions
# Underlying is the ImageMagick toolkit

# --------------------------------------------------------------------------------------


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

