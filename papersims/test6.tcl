#创建事件调度器和节点
set ns [new Simulator]
set node_(s) [$ns node]
set node_(r1) [$ns node]
set node_(r2) [$ns node]
set node_(r3) [$ns node]
set node_(r4) [$ns node]
set node_(d1) [$ns node]
set node_(d2) [$ns node]

$ns at 0 "$node_(s) label s"
$ns at 0 "$node_(r1) label r1"
$ns at 0 "$node_(r2) label r2"
$ns at 0 "$node_(r3) label r3"
$ns at 0 "$node_(r4) label r4"
$ns at 0 "$node_(d1) label d1"
$ns at 0 "$node_(d2) label d2"


#创建输出文件并链接
# set nf [open test6.nam w]
# $ns namtrace-all $nf

#链路设置
$ns duplex-link $node_(s) $node_(r1) 10Mb 2ms DropTail
$ns duplex-link $node_(r1) $node_(r2) 1.5Mb 2ms RED
$ns duplex-link $node_(r2) $node_(d1) 10Mb 2ms DropTail
$ns duplex-link-op $node_(s) $node_(r1) orient right-up
$ns duplex-link-op $node_(r1) $node_(r2) orient right
$ns duplex-link-op $node_(r2) $node_(d1) orient right

# $ns duplex-link $node_(s) $node_(r3) 10Mb 2ms DropTail
# $ns duplex-link $node_(r3) $node_(r4) 3Mb 2ms RED
# $ns duplex-link $node_(r4) $node_(d2) 10Mb 2ms DropTail
# $ns duplex-link-op $node_(s) $node_(r3) orient right-down
# $ns duplex-link-op $node_(r3) $node_(r4) orient right
# $ns duplex-link-op $node_(r4) $node_(d2) orient right

#设置代理
set tcp1 [new Agent/TCP]
$ns attach-agent $node_(s) $tcp1
set sink1 [new Agent/TCPSink]
$ns attach-agent $node_(d1) $sink1
$ns connect $tcp1 $sink1
$tcp1 set packetSize_ 500

# set tcp2 [new Agent/TCP]
# $ns attach-agent $node_(s) $tcp2
# set sink2 [new Agent/TCPSink]
# $ns attach-agent $node_(d2) $sink2
# $ns connect $tcp2 $sink2
# $tcp1 set packetSize_ 500

#设置应用层
set stoptime  20
set num 30
for {set i 0} {$i < $num} {incr i} {
    set pa [new Application/Traffic/MyPareto]
    $pa set packetSize_ 500
    $pa set burst_time_ 320ms
    $pa set idle_time_ 1197ms
    $pa set rate_ 200Kb
    $pa set shape_ 1.2
    $pa attach-agent $tcp1
    $ns at 0.0 "$pa start"

    # set pa2 [new Application/Traffic/MyPareto]
    # $pa2 set packetSize_ 500
    # $pa2 set burst_time_ 320ms
    # $pa2 set idle_time_ 1197ms
    # $pa2 set rate_ 200Kb
    # $pa2 set shape_ 1.2
    # $pa2 attach-agent $tcp2
    # $ns_ at 0.0 "$pa2 start"
}

#设置输出
set mytq [[$ns link $node_(r1) $node_(r2)] queue]
# set mytq2 [[$ns_ link $node_(r3) $node_(s4)] queue]
for {set i 0} {$i < $stoptime} {set i [expr $i+0.5]} {
    $ns at $i "$mytq over"
}


proc finish {} {
	global ns
	$ns flush-trace
	#exec nam test6.nam &
	set f1 [open temp.dr w]
    set f2 [open temp.tp w]
    set f3 [open temp.td w]
    set f4 [open temp.per w]

    puts $f1 "TitleText: $file"
    puts $f1 "Device: Postscript"
    puts $f2 "TitleText: $file"
    puts $f2 "Device: Postscript"
    puts $f3 "TitleText: $file"
    puts $f3 "Device: Postscript"
    puts $f4 "TitleText: $file"
    puts $f4 "Device: Postscript"

    exec cat yzr_queue_dr.txt >@ $f1
    exec cat yzr_queue_tp.txt >@ $f2
    exec cat yzr_queue_td2.txt >@ $f3
    exec cat yzr_perpkt.txt >@ $f4
    close $f
    close $f1
    close $f2
    close $f3
    close $f4

	exit 0
}

$ns at $stoptime "finish"
$ns run





