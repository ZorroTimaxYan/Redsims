###################################
##测试Ared仿真或者Red
##

#创建事件调度器和节点
set ns [new Simulator]
set R1 [$ns node]
set R2 [$ns node]
set D [$ns node]


#创建输出文件并链接
#set nf [open testpareto7.nam w]
#$ns namtrace-all $nf

#创建链路
$ns duplex-link $R1 $R2 8Kb 10ms DropTailT
$ns duplex-link $R2 $D 8Kb 5ms Tque

#设置节点位置
$ns duplex-link-op $R1 $R2 orient right
$ns duplex-link-op $R2 $D orient right


#循环建立n个源节点，并设置传输层和应用层，且链接
#设置仿真时间
set stime 10

set cbr0 [new Agent/CBR]
$ns attach-agent $R1 $cbr0
$cbr0 set packetSize_ 1000
$cbr0 set interval_ 1

set null0 [new Agent/Null]
$ns attach-agent $D $null0

$ns connect $cbr0 $null0

$ns at 0.0 "$cbr0 start"

proc finish {} {
	#清空输出缓存并关闭nam输出文件
	global ns
	#global nf
	$ns flush-trace
	#close $nf
	
	#调用nam打开动画文件进行动画播放
	#exec nam testpareto7.nam &
	exit 0
}

#设置数据源的启动停止时间
$ns at 0.0 "$R1 label r1"
$ns at 0.0 "$R2 label r2"
$ns at 0.0 "$D label d"
$ns at $stime "finish"

$ns run




