set flows [lindex $argv 0]
set rate [lindex $argv 1]
set ecn [lindex $argv 2]
set reverse [lindex $argv 3]
set web [lindex $argv 4]
set bytequeue [lindex $argv 5] ;
set intervals [lindex $argv 6] ; 
set minthresh [lindex $argv 7]
set maxthresh [lindex $argv 8]
set adaptive [lindex $argv 9]
set progname [lindex $argv 10]

set out "rate_$rate.flows_$flows.web_$web.ecn_$ecn.reverse_$reverse.qib_$bytequeue.progname_$progname"

#plot related functions
set quiet "false"
set tchan_ [open "all.q.$out" w]


puts "flows: $flows rate: $rate"
puts "reverse-path traffic: $reverse   ecn: $ecn"
puts "number of web flows/second: $web"
puts "interval: $intervals"
puts "minthresh: $minthresh maxthresh: $maxthresh"

# Reverse-path traffic is half the number of flows as for the forward path.
set stoptime 200

proc stop {} {
	
	global quiet tchan_ out
	if { [info exists tchan_] && $quiet == "false" } {
		plotQueue "$out"
	}
 	exit
}

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


    if { [info exists tchan_] } {
	close $tchan_
    }
    exec rm -f temp.q temp1.q temp2.q
    exec touch temp.q temp1.q temp2.q

    exec awk $awkCode1 all.q.$out

    set gnuplotstr "gnuplot <<!\nset terminal postscript eps\nset xlabel \"Average Queue Length\"\nset ylabel \"Time (in Seconds)\"\nset size 0.8,0.6\nset nokey\nset output \"reda_rt.eps\"\nplot \"temp1.q\" with lines\n!\n"

    set f [open gnuplot.cmd w]
    puts $f $gnuplotstr
    close $f

    if {$quiet == "false"} {
	exec bash gnuplot.cmd
    }
}

proc printall { fmon stoptime rate now } {
    global squeue
    set drops [$fmon set pdrops_]
    set bytes [$fmon set bdepartures_]
    set pkts [$fmon set pdepartures_]
    set totalbytes [expr $now * $rate * 1000000 / 8 ]
    set fracbytes [expr 100 * $bytes / $totalbytes ]
    puts "pkts $pkts, drops $drops, bytes $bytes, totalbytes $totalbytes time $now"
    puts "Q_weight [$squeue set q_weight_]"
    if {$pkts > 0} {
        puts "aggregate per-link drops(%) [expr 100.0*$drops/$pkts ] time $now"
    } else {
       puts "aggregate per-link drops(%) 0 time $now"
    }
    puts "aggregate per-link throughput(%) [expr 100.0*$bytes/$totalbytes ] time $now"
}


set ns [new Simulator]

set node_(r1) [$ns node]
set node_(r2) [$ns node]

#alternate path
set node_(r3) [$ns node]
set node_(r4) [$ns node]

Queue/RED set setbit_ true
Queue/RED set summarystats_ true
Queue/RED set adaptive_ $adaptive
Queue/RED set q_weight_ 0.0
Queue/RED set bytes_ false
Queue/RED set queue_in_bytes_ $bytequeue
Queue/RED set thresh_ $minthresh
Queue/RED set maxthresh_ $maxthresh
Queue/RED set linterm_ 100

set pktsize 1000
Agent/TCP set ecn_ $ecn 
Agent/TCP set packetSize_ $pktsize

set delay 50ms
$ns duplex-link $node_(r1) $node_(r2) [set rate]Mb [set delay]ms RED
$ns duplex-link $node_(r3) $node_(r4) [expr [set rate]/2]Mb [set delay]ms RED
#Agent/TCP set overhead_ [expr 8*$pktsize/($rate*1000000) ]

$ns queue-limit $node_(r1) $node_(r2) 800
$ns queue-limit $node_(r2) $node_(r1) 800
$ns queue-limit $node_(r3) $node_(r4) 800
$ns queue-limit $node_(r4) $node_(r3) 800

set slink [$ns link $node_(r1) $node_(r2)] ; 
set rlink [$ns link $node_(r2) $node_(r1)] ; 
set fmon [$ns makeflowmon Fid]
$ns attach-fmon $slink $fmon
set squeue [$slink queue]
set rqueue [$rlink queue]


# trace related
$squeue attach $tchan_
$squeue trace curq_
$squeue trace ave_
$squeue trace cur_max_p_

proc connection {node1 node2 node3 rate delay} {
    global  ns
    $ns duplex-link $node1 $node2 [set rate]Mb [set delay]ms DropTail
    $ns duplex-link $node1 $node3 [set rate]Mb [set delay]ms DropTail
    $ns cost $node1 $node2 2
    $ns cost $node1 $node3 4
}

# Set up forward TCP connection
for {set i 0} {$i < $flows} {incr i} {
    set node_(s$i) [$ns node]
    set node_(k$i) [$ns node]
    
    connection $node_(s$i) $node_(r1) $node_(r3) 100 2
    connection $node_(k$i) $node_(r2) $node_(r4) 100 2 
#    $ns rtproto DV $node_(s$i) $node_(r1) $node_(r2) $node_(r3) $node_(r4) $node_(k$i)
    set tcp$i [$ns create-connection TCP/Sack1 $node_(s$i) TCPSink/Sack1 $node_(k$i) 0]
    set ftp$i [[set tcp$i] attach-app FTP]
    set starttime 0

    $ns at $starttime "[set ftp$i] start"
    $ns at $stoptime "[set ftp$i] stop"
}


# Traffic on the reverse path.
set randomflows [expr $flows / 2 ]
if {$randomflows > $flows} {
    set randomflows $flows
}
if {$reverse==0} {
    set randomflows 0
}
for {set i 0} {$i < $randomflows} {incr i} {
    set tcp$i [$ns create-connection TCP/Sack1 $node_(k$i) TCPSink/Sack1 $node_(s$i) 1]
    set ftp$i [[set tcp$i] attach-app FTP]
    $ns at $i "[set ftp$i] start"
    $ns at $stoptime "[set ftp$i] stop"
}

# Forward direction web traffic.
set webflows [expr $web*$stoptime]
for {set i 0} {$i < $webflows} {incr i} {
    set node [expr $i%$flows] ; 
    if ![info exists node_(s$node)] {
	set node_(s$node) [$ns node]
	set node_(k$node) [$ns node]
	connection $node_(s$node) $node_(r1) $node_(r3) 100 2 
	connection $node_(k$node) $node_(r2) $node_(r4) 100 2
#	$ns rtporoto DV $node_(s$node) $node_(r1) $node_(r2) $node_(r3) $node_(r4) $node_(k$node)
     }
    set tcp$node [$ns create-connection TCP/Sack1 $node_(s$node) TCPSink/Sack1 $node_(k$node) 2]
    set ftp$node [[set tcp$node] attach-app FTP]
    set sec [expr $i%$stoptime]
    set frac [expr $i%119] ; #some prime 
    set starttime $sec.$frac
    $ns at $starttime "[set ftp$node] produce 10"
}

# Reverse direction web traffic
for {set i 0} {$i < $webflows} {incr i} {
    set node [expr $i%$flows]
    if ![info exists node_(k$node)] {
	set node_(s$node) [$ns node]
	set node_(k$node) [$ns node]
	connection $node_(s$node) $node_(r1) $node_(r3) 100 2 
	connection $node_(k$node) $node_(r2) $node_(r4) 100 2
#	$ns rtporoto DV $node_(s$node) $node_(r1) $node_(r2) $node_(r3) $node_(r4) $node_(k$node)
    }
    set tcp$node [$ns create-connection TCP $node_(k$node) TCPSink $node_(s$node) 2]
    set ftp$node [[set tcp$node] attach-app FTP]
    set sec [expr $i%$stoptime]
    set frac [expr $i%119]
    set starttime $sec.$frac
    $ns at $starttime "[set ftp$node] produce 10"
}


for {set i $intervals} {$i < $stoptime + $intervals} {incr i $intervals} {
  $ns at $i.0 "$squeue printstats"
  $ns at $i.0 "printall $fmon $stoptime $rate $i"
}

#link change
$ns rtproto Session
$ns rtmodel-at 50.0 down $node_(r1) $node_(r2)
$ns rtmodel-at 60.0 up $node_(r1) $node_(r2)

$ns at $stoptime "stop"

$ns run
