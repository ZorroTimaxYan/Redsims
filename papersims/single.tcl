set flows [lindex $argv 0]
set rate [lindex $argv 1]
set linterm [lindex $argv 2]
set ecn [lindex $argv 3]
set minthresh [lindex $argv 4]
set maxthresh [lindex $argv 5]
set reverse [lindex $argv 6]
set web [lindex $argv 7]
set maxp [expr 1.0 / $linterm]
set adaptive [lindex $argv 8]
set q_weight [lindex $argv 9]

puts "flows: $flows rate: $rate maxp: $maxp"
puts "minthresh: $minthresh maxthresh: $maxthresh"
puts "reverse-path traffic: $reverse   ecn: $ecn"
puts "number of web flows: $web adaptive: $adaptive
"
set stoptime 100

proc stop {} {
 	exit
}

proc printall { fmon time rate } {
    global squeue
    set drops [$fmon set pdrops_]
    set bytes [$fmon set bdepartures_]
    set pkts [$fmon set pdepartures_]
    set totalbytes [expr $time * $rate * 1000000 / 8 ]
    set fracbytes [expr 100 * $bytes / $totalbytes ]
    puts "Q_weight [$squeue set q_weight_]"
    puts "aggregate per-link drops(%) [expr 100.0*$drops/($pkts+$drops) ]"
    puts "aggregate per-link throughput(%) [expr 100.0*$bytes/$totalbytes ]"
}


set ns [new Simulator]
set node_(r1) [$ns node]
set node_(r2) [$ns node]
Queue/RED set setbit_ true
Queue/RED set linterm_ $linterm
Queue/RED set summarystats_ true
Queue/RED set adaptive_ $adaptive
Queue/RED set q_weight_ $q_weight

Agent/TCP set ecn_ $ecn 
Agent/TCP set window_ 1000

$ns duplex-link $node_(r1) $node_(r2) [set rate]Mb 20ms RED
source queueSize.tcl
setQueueSize $rate RED $node_(r1) $node_(r2) $minthresh $maxthresh

set slink [$ns link $node_(r1) $node_(r2)]; # link to collect stats on
set fmon [$ns makeflowmon Fid]
$ns attach-fmon $slink $fmon
set squeue [$slink queue]

# Set up TCP connection
for {set i 0} {$i < $flows} {incr i} {
    set node_(s$i) [$ns node]
    set node_(k$i) [$ns node]
    $ns duplex-link $node_(s$i) $node_(r1) 100Mb 2ms DropTail
    $ns duplex-link $node_(k$i) $node_(r2) 100Mb [expr $i/3]ms DropTail
    set tcp$i [$ns create-connection TCP/Sack1 $node_(s$i) TCPSink/Sack1 $node_(k$i) 0]
    set ftp$i [[set tcp$i] attach-app FTP]
    set sec [expr $i/5]
    set frac [expr $i%5]
    set starttime $sec.$frac

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
    [set tcp$i] set window_ 8
    set ftp$i [[set tcp$i] attach-app FTP]
    $ns at 0 "[set ftp$i] start"
    $ns at $stoptime "[set ftp$i] stop"
}

# Forward direction web traffic.
set webflows [expr $web * $stoptime]
for {set i 0} {$i < $flows} {incr i} {
    set node [expr $i%$stoptime]
    set tcp$i [$ns create-connection TCP/Sack1 $node_(s$node) TCPSink/Sack1 $node_(k$node) 2]
    set ftp$i [[set tcp$i] attach-app FTP]
    set frac [expr $i%$web]
    set starttime $node.$frac
    $ns at $starttime "[set ftp$i] produce 10"
}

# Reverse direction web traffic
set webflows [expr $web * $stoptime * $reverse / 2 ]
for {set i 0} {$i < $flows} {incr i} {
    set node [expr $i%$stoptime]
    set tcp$i [$ns create-connection TCP/Sack1 $node_(k$node) TCPSink/Sack1 $node_(s$node) 2]
    set ftp$i [[set tcp$i] attach-app FTP]
    set frac [expr $i%$web]
    set starttime $node.$frac
    $ns at $starttime "[set ftp$i] produce 10"
}


set halftime [expr $stoptime/2.0]
$ns at $halftime "$squeue printstats"
$ns at $stoptime "$squeue printstats"
$ns at $halftime "printall $fmon $halftime $rate"
$ns at $stoptime "printall $fmon $stoptime $rate"
$ns at $stoptime "stop"

$ns run
