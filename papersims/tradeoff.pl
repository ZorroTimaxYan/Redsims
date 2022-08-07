#!/usr/local/bin/perl

sub usage {
print "usage: <progname> flows=<#flows> <filename>\n";
exit;
}

sub process_next {
    print "Processing file $filename\n";
    $filename=$ARGV[0];
}

if ($#ARGV!=1) {usage;}

else {$filename=$ARGV[1];}

$_=shift;
if (m/^flows=(\d+)/) {$flows=$1;} else {usage;}

$yes=0;
$to_print=0;
$read_delay=$read_through=0;
$offset=0;

while (<>) {
    if (m/^interval:\s*(\d+)$/) {$interval=$1;}
    if (m/^flows:\s(\d+)/) {
	if ($to_print) {print "$delay $through\n";$to_print=0;}
	if ($flows==$1) {$yes=1;}
	else {$yes=0;}
    }
    if ($yes) {
	@tokens=split(" ",$_);
	if ($tokens[2]=~m/throughput/) {
	    if ($read_through) {
		$newthrough = $tokens[3];
		$through = 2*$newthrough - $oldthrough;
		$read_through=0;
	    }  
	    else {
		$read_through=1;
		$oldthrough=$tokens[3];
	    }
	}
	if ($tokens[0]=~m/id:/) {$offset=2;}
	if ($tokens[$offset]=~m/True/) {
	    if ($read_delay) {
		$newdelay=$tokens[3+$offset];
		$delay=2*$newdelay-$olddelay;
		$to_print=1;
		$read_delay=0;
	    }
	    else {
		$olddelay=$tokens[3+$offset];
		$read_delay=1;
	    }
	}
    }
}

if ($to_print) {
    print "$delay $through\n";
}
