# csh figure2A.com temp1.queue filename
set filename=$1
set filename3=$2
set first='"queue'
set second='"ave_queue'
awk '{if ($1~/'$first'/) yes=1; if ($1~/'$second'/) yes=0; \
  if(yes==1&&NF==2){print $1, $2;}}' $filename > queue
set first='"ave_queue'
awk '{if ($1~/'$first'/) yes=1; \
  if(yes==1&&NF==2){print $1, $2;}}' $filename > ave_queue
gnuplot << !
# set term post
set terminal postscript eps
set xlabel "Time"
set ylabel "Size (in Packets)"
set output "$filename3.ps"
set key left box
# set key right box
set size 0.8,0.6 
plot "ave_queue" with lines lt 1 lw 4, "queue" with lines lt 0 lw 1
!
