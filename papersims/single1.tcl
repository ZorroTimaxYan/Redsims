#./ns single1.tcl 60 15 100 1 20 60 1 0 1 0 0 RED (without cautious)
#./ns single1.tcl 60 15 100 1 20 60 1 0 1 1 0 RED (with cautious)
#for bad perf. due to non-randomization (slightly better with cautious mode). This has only long-lived flows

#./ns single1.tcl 60 15 100 1 20 60 1 0 1 0 1 RED (without cautious)
#./ns single1.tcl 60 15 100 1 20 60 1 0 1 1 1 RED (with cautious) 
#for good perf due to randomization (2nd is slightly better than 1st.) This also has only long-lived flows.

#The "oscillation" problem is due to non-randomization of propagation delay, and adding web traffic does not make it go away---to see this, we run:
#./ns single1.tcl 60 15 100 1 20 60 1 5 1 0 0 RED (without cautious)
#./ns single1.tcl 60 15 100 1 20 60 1 5 1 1 0 RED (with cautious)
# with 5 ftp-based web flows per second; we still get bad throughput, but cautious is slightly better.

#Similarly with 20 ftp-based web-flows per second:
#./ns single1.tcl 60 15 100 1 20 60 1 20 1 0 0 RED (without cautious)
#./ns single1.tcl 60 15 100 1 20 60 1 20 1 1 0 RED (with cautious)

#likewise with webtraffic generator:
#./ns single1.tcl 60 15 100 1 20 60 1 -1 1 0 0 RED (without cautious)
#./ns single1.tcl 60 15 100 1 20 60 1 -1 1 1 0 RED (with cautious)

set flows [lindex $argv 0]
set rate [lindex $argv 1]
set linterm [lindex $argv 2]
set ecn [lindex $argv 3]
set minthresh [lindex $argv 4]
set maxthresh [lindex $argv 5]

set reverse [lindex $argv 6] 
set web [lindex $argv 7] ; #-1 to activate web traffic generator
set maxp [expr 1.0 / $linterm]
set adaptive [lindex $argv 8]
set cautious [lindex $argv 9]
set random [lindex $argv 10]
#set feng_adaptive [lindex $argv 11]
set control_type [lindex $argv 11]

puts "\nflows: $flows rate: $rate maxp: $maxp"
puts "minthresh: $minthresh maxthresh: $maxthresh"
puts "reverse-path traffic: $reverse   ecn: $ecn"
puts "number of web flows/second: $web adaptive: $adaptive"
puts "cautious: $cautious random: $random " ; # feng_adaptive: $feng_adaptive"
puts "Control type: $control_type"
set stoptime 100


proc stop {} {
 	global quiet tchan_ out
	#if { [info exists tchan_] && $quiet == "false" } {
	#	plotQueue "$out"
	#}
	#global tchan1 ns
	#$ns flush-trace
	#close $tchan1
	exit
    
}

#plot related functions
set out "temp.out"
set quiet "false"
#set tchan_ [open "all.q.$out" w]

proc plotQueue prologue {
    global quiet tchan_ out
	#
	# Plot the queue size and average queue size, for AQM gateways
	#
    set awkCode {
	{
	    if ($1 == "Q" && NF>2) {
		print $2, $3 >> "temp.q";
		set end $2
	    }
	}
    }
    set awkCode1 {
	{
	    if ($1 == "a" && NF>2) {
		print $2, $3 >> "temp1.q";
		set end $2
	    }
	}
    }

#temp.q contains instantaneous queue length, temp1.q contains average queue length; we will just plot instantaneous q.


    if { [info exists tchan_] } {
	close $tchan_
    }
    exec rm -f temp.q temp1.q temp2.q
    exec touch temp.q temp1.q temp2.q

    exec awk $awkCode all.q.$out
    exec awk $awkCode1 all.q.$out

    set gnuplotstr "gnuplot <<!\nset terminal postscript eps\nset ylabel \"Average Queue Length\"\nset xlabel \"Time\"\nset size 1.0,0.8\nset nokey\nset output \"temp1.eps\"\nplot\"temp.q\"with lines\n!\n"

    set f [open gnuplot.cmd w]
    puts $f $gnuplotstr
    close $f

    if {$quiet == "false"} {
	exec bash gnuplot.cmd
    }
}

proc printall { fmon time rate } {
    global squeue control_type
    set drops [$fmon set pdrops_]
    set bytes [$fmon set bdepartures_]
    set pkts [$fmon set pdepartures_]
    set totalbytes [expr $time * $rate * 1000000.0 / 8 ]
    puts "Packets: [set pkts] Bytes: [set bytes]"
    puts "Drops: [set drops]"
    if {$control_type=="RED"} {
	puts "Q_weight [$squeue set q_weight_]"
    }
    puts "aggregate per-link drops(%) [expr 100.0 * $drops/ ($pkts+$drops) ]"
    puts "aggregate per-link throughput(%) [expr 100.0 * (($bytes*1.0)/ $totalbytes) ]"
    puts "LONG LIVED FLOWS---"
    set fcl [$fmon classifier]
    set flow_l [$fcl lookup auto 0 0 4]
    set drops_l [$flow_l set pdrops_]
    set bytes_l [$flow_l set bdepartures_]
    set pkts_l [$flow_l set pdepartures_]
    puts "Packets: [set pkts_l] Bytes: [set bytes_l]"
    puts "Drops: [set drops_l]"
}

remove-all-packet-headers       ;# removes all except common
add-packet-header Flags IP TCP  ;# hdrs reqd for TCP
set ns [new Simulator]

#trace
#puts "Doing traces"
#set tchan1 [open "trace.out" w]
#$ns trace-all $tchan1

set node_(r1) [$ns node]
set node_(r2) [$ns node]
set node_(r3) [$ns node]
Queue/RED set setbit_ true
Queue/RED set linterm_ $linterm
Queue/RED set summarystats_ true
Queue/RED set adaptive_ $adaptive
Queue/RED set bytes_ true
Queue/RED set queue_in_bytes_ true ; #changed!
#Queue/RED set queue_in_bytes_ true
#Queue/RED set q_weight_ -1
Queue/RED set q_weight_ 0.002
Queue/DropTail set summarystats_ true
Queue/RED set cautious_ $cautious

if {0} {
    if {$feng_adaptive} {
	Queue/RED set feng_adaptive_ 1
	Queue/RED set alpha_ 3
	Queue/RED set beta_ 2
    }
}

Agent/TCP set ecn_ $ecn 
Agent/TCP set window_ 1000
set pktsize 500
Agent/TCP set packetSize_ $pktsize
#Agent/TCP set overhead_ [expr 8*$pktsize/($rate*1000000) ]
#Agent/TCP set overhead_ 0

if {$control_type=="DropTail"} {
    Queue/RED set q_weight_ 1
    Queue/RED set thresh_ 1000
    Queue/RED set maxthresh_ 1000
    $ns duplex-link $node_(r1) $node_(r2) [expr $rate]Mb 20ms DropTail
    $ns queue-limit  $node_(r1) $node_(r2)  [expr $maxthresh]
    $ns queue-limit $node_(r2) $node_(r1) [expr $maxthresh]
} else {
    Queue/RED set thresh_ $minthresh
    Queue/RED set maxthresh_ $maxthresh
    $ns duplex-link $node_(r1) $node_(r2) [set rate]Mb 20ms RED
    $ns queue-limit  $node_(r1) $node_(r2) 1000 ;
    $ns queue-limit  $node_(r2) $node_(r1) 1000 ;
}

set slink [$ns link $node_(r1) $node_(r2)] ; # link to collect stats on
set fmon [$ns makeflowmon Fid]
$ns attach-fmon $slink $fmon
set squeue [$slink queue]
set rlink [$ns link $node_(r2) $node_(r1)] ; # link to collect stats on
set fmonr [$ns makeflowmon Fid]
$ns attach-fmon $rlink $fmonr
set rqueue [$rlink queue]

# trace related
if {$control_type=="RED"} {
#    $squeue attach $tchan_
#    $squeue trace curq_
#    $squeue trace ave_
#    $squeue trace cur_max_p_
#    $squeue set print_idle_ true
} elseif {$control_type=="DropTail"} {
#    $squeue set print_idle_ true
#    $rqueue set print_idle_ true
#    $squeue attach $tchan_
#    $squeue trace curq_
}

if {$random} {
    ns-random 0
} 

# Set up TCP connection
for {set i 0} {$i < $flows} {incr i} {
    set node_(s$i) [$ns node]
    set node_(k$i) [$ns node]

    #if {$i%2==0} {
	set dest $node_(r2)
    #} else {
	#set dest $node_(r3)
    #}
    if {$random} {
	$ns duplex-link $node_(s$i) $node_(r1) 100Mb [expr 4.0*([ns-random]/2147483647.0)]ms DropTail
    } else {
	$ns duplex-link $node_(s$i) $node_(r1) 100Mb [expr $i/3] DropTail
	#$ns duplex-link $node_(s$i) $node_(r1) 100Mb 2ms DropTail
    }
    $ns queue-limit $node_(s$i) $node_(r1) 1000
    $ns queue-limit $node_(r1) $node_(s$i) 1000

    if {$random} {
	$ns duplex-link $node_(k$i) $dest 100Mb [expr 4.0*([ns-random]/2147483647.0)]ms DropTail
    } else {
	$ns duplex-link $node_(k$i) $node_(r2) 100Mb [expr $i/3]ms DropTail
	#$ns duplex-link $node_(k$i) $node_(r2) 1000Mb 2ms DropTail
    }
    $ns queue-limit $dest $node_(k$i) 1000
    $ns queue-limit $node_(k$i) $dest 1000

    #set tcp$i [$ns create-connection TCP/Newreno $node_(s$i) TCPSink/DelAck $node_(k$i) 4]
    set tcp$i [$ns create-connection TCP/Sack1 $node_(s$i) TCPSink/Sack1 $node_(k$i) 4] ;
    set ftp$i [[set tcp$i] attach-app FTP]
    set sec [expr $i/5]
    set frac [expr $i%5]
    set starttime $sec.$frac

    $ns at $starttime "[set ftp$i] start"
    $ns at $stoptime "[set ftp$i] stop"
}

# Traffic on the reverse path.
#set randomflows [expr $flows / 2 ]
set randomflows $flows
if {$randomflows > $flows} {
    set randomflows $flows
}
if {$reverse==0} {
    set randomflows 0
}
for {set i 0} {$i < $randomflows} {incr i} {
    #set tcp$i [$ns create-connection TCP/Newreno $node_(k$i) TCPSink/DelAck $node_(s$i) 4]
    set tcp$i [$ns create-connection TCP/Sack1 $node_(k$i) TCPSink/Sack1 $node_(s$i) 4]
    #    [set tcp$i] set window_ 8
    set ftp$i [[set tcp$i] attach-app FTP]
    set sec [expr $i/5]
    set frac [expr $i%5]
    set starttime $sec.$frac
    $ns at $starttime "[set ftp$i] start"
    $ns at $stoptime "[set ftp$i] stop"
}

#################################################
PagePool/WebTraf set TCPTYPE_ Sack1
PagePool/WebTraf set TCPSINKTYPE_ TCPSink/Sack1
#PagePool/WebTraf set TCPTYPE_ Newreno
#PagePool/WebTraf set TCPSINKTYPE_ TCPSink/DelAck
#PagePool/WebTraf set FID_ASSIGNING_MODE_ 1

proc add_web_nodes {bdel randomize} {
  global ns
  global node_
  global s_
  global r_
  global count

	if {$randomize == 0} {
  	set x [expr $bdel/2]ms
  	set y [expr $bdel/2]ms
	} else {
		set x [ns-random]
		set y [ns-random]
		set x [expr 4*$bdel*($x/2147483647.0)]ms
		set y [expr 4*$bdel*($y/2147483647.0)]ms
	    #puts "Values of x and y are $x $y"
	}
  set i $count
  set s_($i) [$ns node]
  set r_($i) [$ns node]
  $ns duplex-link $s_($i) $node_(r1) 100Mb $x DropTail
  $ns queue-limit $s_($i) $node_(r1) 1000
  $ns queue-limit $node_(r1) $s_($i) 1000

  $ns duplex-link $r_($i) $node_(r2) 100Mb $y DropTail
  $ns queue-limit $r_($i) $node_(r2) 1000
  $ns queue-limit $node_(r2) $r_($i) 1000

  incr count
}

proc add_web_traffic {bdel nums ip ps os} {
    global ns
    global node_
    global s_
    global r_
    global count
    global pool

    set numWeb 10
    set pool [new PagePool/WebTraf]
    $pool set-num-client $numWeb
    $pool set-num-server $numWeb
    
    for {set i 0} {$i < $numWeb} {incr i} {
  	add_web_nodes $bdel 1
	if {$i%2==0} {
	    $pool set-server $i $s_([expr $count - 1])
	    $pool set-client $i $r_([expr $count - 1])
	} else {
	    $pool set-server $i $r_([expr $count - 1])
	    $pool set-client $i $s_([expr $count - 1])
	}
    }
    $pool set-num-session $nums
    set numPage 1000
    for {set i 0} {$i < $nums} {incr i} {
  	set interPage [new RandomVariable/Exponential]
  	$interPage set avg_ $ip
  	set pageSize [new RandomVariable/Constant]
  	$pageSize set val_ $ps
	#set pageSize [new RandomVariable/Exponential]
	#$pageSize set avg_ $ps
  	set interObj [new RandomVariable/Exponential]
  	$interObj set avg_ [expr 0.01]
  	set objSize [new RandomVariable/ParetoII]
  	$objSize set avg_ $os
  	$objSize set shape_ 1.2
  	$pool create-session $i $numPage 0 $interPage $pageSize $interObj $objSize
    }
}

set count 0

if {$web == -1} {
    #add_web_traffic 8 8 1 40 80
    if {$rate <= 15} {
	#puts "Using lighter traffic"
	add_web_traffic 2 2 1 20 40 ; #orig
	#add_web_traffic 2 4 1 40 40 ; #new
    } else {
	#puts "Using heavier traffic"
	add_web_traffic 2 6 1 40 80
    }
}

#################################################

# Forward direction web traffic.
set webflows [expr $web * $stoptime]
for {set i 0} {$i < $webflows} {incr i} {
    #set node [expr $i%$stoptime]
    if {$flows<=0} {
	puts "Must have flows >=0 in order to use short ftp as web transfers"
	exit -1
    } else {
	set node [expr $i%$flows]
    }
    set tcp$i [$ns create-connection TCP/Sack1 $node_(s$node) TCPSink/Sack1 $node_(k$node) 2]
    set ftp$i [[set tcp$i] attach-app FTP]
    set frac [expr $i%$web]
    set starttime $node.$frac
    $ns at $starttime "[set ftp$i] produce 10"
}

# Reverse direction web traffic
if {$reverse > 0} {set reversetraffic 1} else {set reversetraffic 0}
set webflows [expr $web * $stoptime * $reversetraffic]
for {set i 0} {$i < $webflows} {incr i} {
    #set node [expr $i%$stoptime]
    if {$flows<=0} {
	puts "Must have flows >=0 in order to use short ftp as web transfers"
	exit -1
    } else {
	set node [expr $i%$flows]
    }
    set tcp$i [$ns create-connection TCP/Sack1 $node_(k$node) TCPSink/Sack1 $node_(s$node) 2]
    set ftp$i [[set tcp$i] attach-app FTP]
    set frac [expr $i%$web]
    set starttime $node.$frac
    $ns at $starttime "[set ftp$i] produce 10"
}

set halftime [expr $stoptime/2.0]
set hafltime- [expr $halftime - 0.001]
$ns at $halftime- "puts FORWARD---"
$ns at $halftime- "$squeue printstats"
$ns at $halftime- "printall $fmon $halftime $rate"
#$ns at $halftime "puts REVERSE---"
#$ns at $halftime "$rqueue printstats"
#$ns at $halftime "printall $fmonr $halftime $rate"

set stoptime- [expr $halftime - 0.001]
$ns at $stoptime- "puts FORWARD---"
$ns at $stoptime- "$squeue printstats"
$ns at $stoptime- "printall $fmon $stoptime $rate"
#$ns at $stoptime "puts REVERSE---"
#$ns at $stoptime "$rqueue printstats"
#$ns at $stoptime "printall $fmonr $stoptime $rate"
$ns at $stoptime "stop"

$ns run

################

