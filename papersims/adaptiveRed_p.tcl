#
# Copyright (c) 1995-1997 The Regents of the University of California.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgement:
#   This product includes software developed by the Computer Systems
#   Engineering Group at Lawrence Berkeley Laboratory.
# 4. Neither the name of the University nor of the Laboratory may be used
#    to endorse or promote products derived from this software without
#    specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# @(#) $Header: /usr/local/share/doc/apache/cvs/autored/sims/adaptiveRed.tcl,v 1.9 2001/07/31 05:47:18 floyd Exp $
#

source misc_simple.tcl
source support1.tcl
Queue/RED set summarystats_ true
Queue/RED set q_weight_ 0.0
Queue/RED set minthresh 0
Queue/RED set maxthresh 0

set flowfile fairflow.tr; # file where flow data is written
set flowgraphfile fairflow.xgr; # file given to graph tool 

TestSuite instproc finish file {
    global quiet PERL
    $self instvar ns_ tchan_ testName_
        exec $PERL getrc -s 2 -d 3 all.tr | \
          $PERL raw2xg -a -s 0.01 -m 90 -t $file > temp.rands
    if {$quiet == "false"} {
           # exec xgraph -bb -tk -nl -m -x time -y packets temp.rands &
    }
        ## now use default graphing tool to make a data file
        ## if so desired

    if { [info exists tchan_] && $quiet == "false" } {
        $self plotQueue $testName_
    }
    $ns_ halt
}

TestSuite instproc enable_tracequeue ns {
    $self instvar tchan_ node_
    set redq [[$ns link $node_(r1) $node_(r2)] queue]
    set tchan_ [open all.q w]
    $redq trace curq_
    $redq trace ave_
    $redq attach $tchan_
}

Class Topology

Topology instproc node? num {
    $self instvar node_
    return $node_($num)
}

Class Topology/net2 -superclass Topology
Topology/net2 instproc init ns {
    $self instvar node_
    set node_(s1) [$ns node]
    set node_(s2) [$ns node]    
    set node_(r1) [$ns node]    
    set node_(r2) [$ns node]    
    set node_(s3) [$ns node]    
    set node_(s4) [$ns node]    

    $self next 

    $ns duplex-link $node_(s1) $node_(r1) 10Mb 2ms DropTail
    $ns duplex-link $node_(s2) $node_(r1) 10Mb 3ms DropTail
    $ns duplex-link $node_(r1) $node_(r2) 1.5Mb 20ms RED
    #限制包数为35
    $ns queue-limit $node_(r1) $node_(r2) 35 
    $ns queue-limit $node_(r2) $node_(r1) 35
    # A 1500-byte packet has a transmission time of 0.008 seconds.
    # A queue of 25 1500-byte packets would be 0.2 seconds. 
    $ns duplex-link $node_(r2) $node_(s3) 10Mb 4ms DropTailT
    $ns duplex-link $node_(s4) $node_(r2) 10Mb 5ms DropTail

}   

Class Topology/net3 -superclass Topology
Topology/net3 instproc init ns {
    $self instvar node_
    set node_(s1) [$ns node]
    set node_(s2) [$ns node]    
    set node_(r1) [$ns node]    
    set node_(r2) [$ns node]    
    set node_(s3) [$ns node]    
    set node_(s4) [$ns node]    

    $self next 

    $ns duplex-link $node_(s1) $node_(r1) 10Mb 0ms DropTail
    $ns duplex-link $node_(s2) $node_(r1) 10Mb 1ms DropTail
    $ns duplex-link $node_(r1) $node_(r2) 1.5Mb 10ms RED
    $ns duplex-link $node_(r2) $node_(r1) 1.5Mb 10ms RED
    $ns queue-limit $node_(r1) $node_(r2) 100
    $ns queue-limit $node_(r2) $node_(r1) 100
    $ns duplex-link $node_(s3) $node_(r2) 10Mb 2ms DropTail
    $ns duplex-link $node_(s4) $node_(r2) 10Mb 3ms DropTail
}   

Class Topology/netfast -superclass Topology
Topology/netfast instproc init ns {
    $self instvar node_
    set node_(s1) [$ns node]
    set node_(s2) [$ns node]
    set node_(r1) [$ns node]
    set node_(r2) [$ns node]
    set node_(s3) [$ns node]
    set node_(s4) [$ns node]

    $self next

    $ns duplex-link $node_(s1) $node_(r1) 100Mb 2ms DropTail
    $ns duplex-link $node_(s2) $node_(r1) 100Mb 3ms DropTail
    $ns duplex-link $node_(r1) $node_(r2) 15Mb 20ms RED   
    $ns queue-limit $node_(r1) $node_(r2) 1000
    $ns queue-limit $node_(r2) $node_(r1) 1000
    $ns duplex-link $node_(s3) $node_(r2) 100Mb 4ms DropTail
    $ns duplex-link $node_(s4) $node_(r2) 100Mb 5ms DropTail
}

TestSuite instproc plotQueue file {
    global quiet
    $self instvar tchan_
    #
    # Plot the queue size and average queue size, for RED gateways.
    #
    set awkCode {
        {
            if ($1 == "Q" && NF>2) {
                print $2, $3 >> "temp.q";
                set end $2
            }
            else if ($1 == "a" && NF>2)
                print $2, $3 >> "temp.a";
        }
    }
    exec rm -f temp.dr temp.tp temp.td temp.per

    set f [open temp.queue w]
    set f1 [open temp.dr w]
    set f2 [open temp.tp w]
    set f3 [open temp.td w]
    set f4 [open temp.per w]

    puts $f "TitleText: $file"
    puts $f "Device: Postscript"
    puts $f1 "TitleText: $file"
    puts $f1 "Device: Postscript"
    puts $f2 "TitleText: $file"
    puts $f2 "Device: Postscript"
    puts $f3 "TitleText: $file"
    puts $f3 "Device: Postscript"
    puts $f4 "TitleText: $file"
    puts $f4 "Device: Postscript"


    if { [info exists tchan_] } {
        close $tchan_
    }
    exec rm -f temp.q temp.a 
    exec touch temp.a temp.q

    exec awk $awkCode all.q

    puts $f \"queue
    exec cat temp.q >@ $f  
    puts $f \n\"ave_queue
    exec cat temp.a >@ $f

    exec cat yzr_queue_dr.txt >@ $f1
    exec cat yzr_queue_tp.txt >@ $f2
    exec cat yzr_queue_td2.txt >@ $f3
    exec cat yzr_perpkt.txt >@ $f4

    ###puts $f \n"thresh
    ###puts $f 0 [[ns link $r1 $r2] get thresh]
    ###puts $f $end [[ns link $r1 $r2] get thresh]
    close $f
    close $f1
    close $f2
    close $f3
    close $f4
    if {$quiet == "false"} {
        #puts aaa
        exec xgraph -bb -tk -x time -y queue temp.queue &
        exec xgraph -bb -tk -x time -y rate temp.dr &
        exec xgraph -bb -tk -x time -y packets/s temp.tp &
        exec xgraph -x time -y ms temp.td &
        exec xgraph -x time -y packets temp.per &
        if {$file == "transient" || $file == "transient1" || 
            $file == "transient2" } {
                exec csh gnuplotB.com temp.queue $file
        } else {
            exec csh gnuplotA.com temp.queue $file
        }
    }
}

TestSuite instproc tcpDumpAll { tcpSrc interval label } {
    global quiet
    $self instvar dump_inst_ ns_
    if ![info exists dump_inst_($tcpSrc)] {
    set dump_inst_($tcpSrc) 1
    set report $label/window=[$tcpSrc set window_]/packetSize=[$tcpSrc set packetSize_]
    if {$quiet == "false"} {
        puts $report
    }
    $ns_ at 0.0 "$self tcpDumpAll $tcpSrc $interval $label"
    return
    }
    $ns_ at [expr [$ns_ now] + $interval] "$self tcpDumpAll $tcpSrc $interval $label"
    set report time=[$ns_ now]/class=$label/ack=[$tcpSrc set ack_]/packets_resent=[$tcpSrc set nrexmitpack_]
    if {$quiet == "false"} {
        puts $report
    }
}       

TestSuite instproc setTopo {} {
    $self instvar node_ net_ ns_

    set topo_ [new Topology/$net_ $ns_]
    set node_(s1) [$topo_ node? s1]
    set node_(s2) [$topo_ node? s2]
    set node_(s3) [$topo_ node? s3]
    set node_(s4) [$topo_ node? s4]
    set node_(r1) [$topo_ node? r1]
    set node_(r2) [$topo_ node? r2]

    [$ns_ link $node_(r1) $node_(r2)] trace-dynamics $ns_ stdout

}

TestSuite instproc maketraffic {} {
    $self instvar ns_ node_ testName_ net_ tinterval_ 
    set stoptime  50

    set fmon [$self setMonitor $node_(r1) $node_(r2)]

    set tcp1 [$ns_ create-connection TCP/Sack1 $node_(s1) TCPSink/Sack1 $node_(s3) 0]
    $tcp1 set window_ 15

    set tcp2 [$ns_ create-connection TCP/Sack1 $node_(s2) TCPSink/Sack1 $node_(s3) 1]
    $tcp2 set window_ 15

    set tcp3 [$ns_ create-connection TCP/Sack1 $node_(s3) TCPSink/Sack1 $node_(s1) 3]
    $tcp3 set window_ 15

    #set ftp1 [$tcp1 attach-app FTP]
    #set ftp2 [$tcp2 attach-app FTP]
    set ftp3 [$tcp3 attach-app FTP]

    set num 15
    for {set i 0} {$i < $num} {incr i} {
        set pa [new Application/Traffic/MyPareto]
        $pa set packetSize_ 500
        $pa set burst_time_ 320ms
        $pa set idle_time_ 1197ms
        $pa set rate_ 200Kb
        $pa set shape_ 1.2
        $pa attach-agent $tcp1
        $ns_ at 0.0 "$pa start"

        set pa2 [new Application/Traffic/MyPareto]
        $pa2 set packetSize_ 500
        $pa2 set burst_time_ 320ms
        $pa2 set idle_time_ 1197ms
        $pa2 set rate_ 200Kb
        $pa2 set shape_ 1.2
        $pa2 attach-agent $tcp2
        $ns_ at 0.0 "$pa2 start"
    }


    $self enable_tracequeue $ns_
    #$ns_ at 0.0 "$ftp1 start"
    #$ns_ at 3.0 "$ftp2 start" 
    $ns_ at 1.0 "$ftp3 start"
    set halftime [expr $stoptime / 2]
    $ns_ at $halftime "printall $fmon $stoptime 1.5"
    $ns_ at $stoptime "printall $fmon $stoptime 1.5"
    set slink [$ns_ link $node_(r1) $node_(r2)]
    set squeue [$slink queue]
    $ns_ at $halftime "$squeue printstats"
    $ns_ at $stoptime "$squeue printstats"

    $self tcpDump $tcp1 5.0
    # trace only the bottleneck link
    #$self traceQueues $node_(r1) [$self openTrace $stoptime $testName_]
    $ns_ at $stoptime "$self cleanupAll $testName_"

    set mytq [[$ns_ link $node_(r1) $node_(r2)] queue]
    set mytq2 [[$ns_ link $node_(r2) $node_(s3)] queue]
    for {set i 0} {$i < $stoptime} {set i [expr $i+$tinterval_]} {
        $ns_ at $i "$mytq over"
        $ns_ at $i "$mytq2 putTime"
    }
}

#####################################################################

Class Test/red1 -superclass TestSuite
Test/red1 instproc init {} {
    $self instvar net_ test_
    set net_ net2 
    set test_ red1
    $self next
}
Test/red1 instproc run {} {
    $self instvar ns_ node_ testName_ net_
    $self setTopo
    $self maketraffic 
    $ns_ run
}

Class Test/red1Adapt -superclass TestSuite
Test/red1Adapt instproc init {} {
    $self instvar net_ test_ ns_
    set net_ net2 
    set test_ red1Adapt
    Queue/RED set alpha_ 0.01
    Queue/RED set beta_ 0.9

    $self next
}
Test/red1Adapt instproc run {} {
    $self instvar ns_ node_ testName_ net_
    $self setTopo
    set forwq [[$ns_ link $node_(r1) $node_(r2)] queue]
    $forwq set adaptive_ 1 
    $self maketraffic
    $ns_ run   
}

#####################################################################

TestSuite instproc newtraffic { num window packets start interval } {
    $self instvar ns_ node_ testName_ net_

    for {set i 0} {$i < $num } {incr i} {
        set tcpi [$ns_ create-connection TCP/Sack1 $node_(s1) TCPSink/Sack1 $node_(s3) 2]
        $tcpi set window_ $window
        set pa [new Application/Traffic/MyPareto]
        $pa set packetSize_ 500
        $pa set burst_time_ 320ms
        $pa set idle_time_ 1197ms
        $pa set rate_ 200Kb
        $pa set shape_ 1.2
        $pa attach-agent $tcpi
        $ns_ at 0.0 "$pa start"
    }
}
Class Test/red2 -superclass TestSuite
Test/red2 instproc init {} {
    $self instvar net_ test_ tinterval_
    set net_ net2 
    set test_ red2
    set tinterval_ 0.5
    Queue/RED set pertime_ $tinterval_
    $self next
}
Test/red2 instproc run {} {
    $self instvar ns_ node_ testName_ net_
    $self setTopo
    $self maketraffic 
    #$self newtraffic 10 20 1000 25 0.1
    $ns_ run
}

Class Test/red2Adapt -superclass TestSuite
Test/red2Adapt instproc init {} {
    $self instvar net_ test_ ns_ tinterval_
    set net_ net2 
    set test_ red2Adapt
    set tinterval_ 0.5
    Queue/RED set adaptive_ 1
    Queue/RED set pertime_ $tinterval_
    Test/red2Adapt instproc run {} [Test/red2 info instbody run]
    $self next
}

Class Test/red2Padapt -superclass TestSuite
Test/red2Padapt instproc init {} {
    $self instvar net_ test_ ns_ tinterval_
    set net_ net2 
    set test_ red2Padapt
    set tinterval_ 0.5
    Queue/RED set pared_ 1
    Queue/RED set pertime_ $tinterval_
    Test/red2Padapt instproc run {} [Test/red2 info instbody run]
    $self next
}

Class Test/red2Hadapt -superclass TestSuite
Test/red2Hadapt instproc init {} {
    $self instvar net_ test_ ns_ tinterval_
    set net_ net2 
    set test_ red2Hadapt
    set tinterval_ 0.5
    Queue/RED set hared_ 1
    Queue/RED set pertime_ $tinterval_
    Test/red2Hadapt instproc run {} [Test/red2 info instbody run]
    $self next
}

Class Test/red2A-Adapt -superclass TestSuite
Test/red2A-Adapt instproc init {} {
    $self instvar net_ test_ ns_
    set net_ net2 
    set test_ red2A-Adapt
    Queue/RED set alpha_ 0.02
    Queue/RED set beta_ 0.8
    Test/red2A-Adapt instproc run {} [Test/red2 info instbody run ]
    $self next
}

#####################################################################

TestSuite instproc newtraffic1 { num window packets start interval } {
    $self instvar ns_ node_ testName_ net_

    for {set i 0} {$i < $num } {incr i} {
        set tcpi [$ns_ create-connection TCP/Sack1 $node_(s1) TCPSink/Sack1 $node_(s3) 2]
        $tcpi set window_ $window
        set ftpi [$tcpi attach-app FTP]
    set time [expr $start + $i * $interval]
        $ns_ at $time  "$ftpi start"
    $ns_ at 25.0 "$ftpi stop"
    }
}

Class Test/red3 -superclass TestSuite
Test/red3 instproc init {} {
    $self instvar net_ test_
    set net_ net2 
    set test_ red3
    $self next
}
Test/red3 instproc run {} {
    $self instvar ns_ node_ testName_ net_
    $self setTopo
    $self maketraffic 
    $self newtraffic1 15 20 300 0 0.1
    $ns_ run
}

Class Test/red3Adapt -superclass TestSuite
Test/red3Adapt instproc init {} {
    $self instvar net_ test_ ns_
    set net_ net2 
    set test_ red3Adapt
    Queue/RED set adaptive_ 1
    Test/red3Adapt instproc run {} [Test/red3 info instbody run ]
    $self next
}

#####################################################################

Class Test/red4Adapt -superclass TestSuite
Test/red4Adapt instproc init {} {
    $self instvar net_ test_ ns_
    set net_ net2 
    set test_ red4Adapt
    Queue/RED set alpha_ 0.02
    Queue/RED set beta_ 0.8
    Test/red4Adapt instproc run {} [Test/red3Adapt info instbody run ]
    $self next
}



Class Test/transient -superclass TestSuite
Test/transient instproc init {} {
    $self instvar net_ test_
    set net_ netfast 
    set test_ transient
    Queue/RED set q_weight_ 0.002 
    $self next
}
Test/transient instproc run {} {
    $self instvar ns_ node_ testName_ net_
    $self setTopo
    set stoptime 10.0
    set tcp1 [$ns_ create-connection TCP/Sack1 $node_(s1) TCPSink/Sack1 $node_(s3) 0]
    $tcp1 set window_ 100

    set tcp2 [$ns_ create-connection TCP/Sack1 $node_(s2) TCPSink/Sack1 $node_(s3) 1]
    $tcp2 set window_ 1000

    set ftp1 [$tcp1 attach-app FTP]
    set ftp2 [$tcp2 attach-app FTP]

    $self enable_tracequeue $ns_
    $ns_ at 0.0 "$ftp1 start"
    $ns_ at 2.5 "$ftp2 start"

    $self tcpDump $tcp1 5.0
    # trace only the bottleneck link
    #$self traceQueues $node_(r1) [$self openTrace $stoptime $testName_]
    $ns_ at $stoptime "$self cleanupAll $testName_"
    $ns_ run
}

Class Test/transient1 -superclass TestSuite
Test/transient1 instproc init {} {
    $self instvar net_ test_
    set net_ netfast 
    set test_ transient1
    Queue/RED set q_weight_ 0
    Test/transient1 instproc run {} [Test/transient info instbody run ]
    $self next
}

Class Test/transient2 -superclass TestSuite
Test/transient2 instproc init {} {
    $self instvar net_ test_
    set net_ netfast 
    set test_ transient2
    Queue/RED set q_weight_ 0.0001
    Test/transient2 instproc run {} [Test/transient info instbody run ]
    $self next
}

TestSuite runTest