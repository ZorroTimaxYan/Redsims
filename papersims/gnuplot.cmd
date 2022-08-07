gnuplot <<!
set terminal postscript eps
set xlabel "Average Queue Length"
set ylabel "Time (in Seconds)"
set size 0.8,0.6
set nokey
set output "reda_rt.eps"
plot "temp1.q" with lines
!

