proc setQueueSize {rate queue node1 node2 minthresh maxthresh } {
global ns 
switch $rate {
    60 {
	# 7500 pkts/sec, for 1000-byte packets
        $ns queue-limit $node1 $node2 1000
        $ns queue-limit $node2 $node1 1000
        if {$queue=="RED"} {
            set redq [[$ns link $node1 $node2] queue]
	    if {$minthresh=="0"} { 
                $redq set thresh_ 20
            } else { $redq set thresh_ $minthresh
	    }
	    if {$maxthresh=="0"} {
                $redq set maxthresh_ 60
            } else { $redq set maxthresh_ $maxthresh
	    }
        }
    }
    100 {
	# 7500 pkts/sec, for 1000-byte packets
        $ns queue-limit $node1 $node2 1000
        $ns queue-limit $node2 $node1 1000
        if {$queue=="RED"} {
            set redq [[$ns link $node1 $node2] queue]
	    if {$minthresh=="0"} { 
                $redq set thresh_ 20
            } else { $redq set thresh_ $minthresh
	    }
	    if {$maxthresh=="0"} {
                $redq set maxthresh_ 60
            } else { $redq set maxthresh_ $maxthresh
	    }
        }
    }
    15 {
	# 1875 pkts/sec, for 1000-byte packets
        if {$queue=="RED"} {
	    $ns queue-limit $node1 $node2 1000
	    $ns queue-limit $node2 $node1 1000
            set redq [[$ns link $node1 $node2] queue]
	    if {$minthresh=="0"} {
                $redq set thresh_ 10
            } else { 
		$redq set thresh_ $minthresh
	    }
	    if {$maxthresh=="0"} {
                $redq set maxthresh_ 60
            } else { 
		$redq set maxthresh_ $maxthresh
	    }
        }
	if {$queue=="DT"} {
	    $ns queue-limit $node1 $node2 $minthresh
	    $ns queue-limit $node2 $node1 $minthresh
	    set redq [[$ns link $node1 $node2] queue]
	    $redq set thresh_ $minthresh
	    $redq set maxthresh_ $minthresh
	}
    }
    1.5 {
	## 187 pkts/sec, for 1000-byte packets
        $ns queue-limit $node1 $node2 25
        $ns queue-limit $node2 $node1 25
        if {$queue=="RED"} {
            set redq [[$ns link $node1 $node2] queue]
	    if {$minthresh=="0"} {
                $redq set thresh_ 3
            } else { 
		$redq set thresh_ $minthresh
	    }
	    if {$maxthresh=="0"} {
                $redq set maxthresh_ 9
            } else { 
		$redq set maxthresh_ $maxthresh
	    }
        }
    }
}
}

