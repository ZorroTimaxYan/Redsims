proc printall { fmon stoptime rate } {
        set drops [$fmon set pdrops_]
	set bytes [$fmon set bdepartures_]
	set pkts [$fmon set pdepartures_]
	set totalbytes [expr $stoptime * $rate * 1000000 / 8 ]
        set fracbytes [expr 100 * $bytes / $totalbytes ]
        #puts "aggregate per-link total_drops $drops"
        #puts "aggregate per-link total_packets $pkts"
	puts "aggregate per-link drops(%) [expr 100.0*$drops/$pkts ]"
        #puts "aggregate per-link total_bytes $bytes"
	#puts "aggregate per-link totalbytes $totalbytes"
	puts "aggregate per-link throughput(%) [expr 100.0*$bytes/$totalbytes ]"
}

TestSuite instproc setMonitor {node1 node2} {
	$self instvar ns_
	set slink [$ns_ link $node1 $node2]; # link to collect stats on
	set fmon [$ns_ makeflowmon Fid]
	$ns_ attach-fmon $slink $fmon
	set squeue [$slink queue]
	return $fmon
}

