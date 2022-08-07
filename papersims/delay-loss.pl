#!/usr/local/bin/perl

print "This script takes the output file produced by single1.run, crunches
it for delay/drop, and runs it through gnuplot to generate .eps files\n";
$filename=shift;
$title=shift;

@flows=(5,10,20,30,40,50,60,70,80,90,100);
%iters=(loss=>"\"Link Loss\"");
$gnuplotstr="";
foreach $iter (keys %iters) {
    foreach $flow (@flows) {
	$execstr="./tradeoff.$iter.pl flows=$flow $filename";
	open INPUT, "$execstr |";
	$filestr="$flow" . " flows";
	open OUTPUT, ">$filestr";
	while (<INPUT>) {
	    print OUTPUT $_;
	}
    }

    $gnuplotstr= 'gnuplot << !
set terminal postscript eps 
set xlabel "Average Queue Length"
' . "set ylabel $iters{$iter}\n" . '
#set nokey
set key left bottom box
set size 0.8,0.6
' . "set output \"delay-loss.eps\"\n";

    if ($iter=~/util/) {
	$gnuplotstr.='
set arrow from 47.175,100 to 56.59,100 nohead
set arrow from 56.59,100 to 56.59,98.12 nohead
set arrow from 56.59,98.12 to 47.175,98.12 nohead
set arrow from 47.175,98.12 to 47.175,100 nohead
set key right bottom box
';
	$gnuplotstr .="plot [10:90] [86:100]";
    } elsif ($iter=~/loss/) {
	$gnuplotstr.='
set key top box
set yrange [0:0.1]
' . "plot ";
    }
    $nelements=$#flows;
    $cnt=0;
    foreach $flow (@flows) {
	$filestr="$flow"." flows";
	if ($cnt<$nelements) {
	    if ($iter=~/util/) {
		$tempstr=" with linespoints pt 2, ";
	    } 
	    if ($iter=~/loss/) {
		$tempstr=" with lines, ";
	    }
	    $gnuplotstr .= "\"$filestr\"" . $tempstr;
	    $cnt++;
	}
	else {
	    if ($iter=~/util/) {
		$gnuplotstr .= "\"$filestr\" with linespoints pt 2;\n";
	    } 
	    if ($iter=~/loss/) {
		$gnuplotstr .= "\"$filestr\" with lines;\n";
	    }
	}
    }
    $gnuplotstr .="!\n";
    open OUTPUT, ">gnuplot.cmd";
    print OUTPUT $gnuplotstr;
    system bash, "gnuplot.cmd"
    }
