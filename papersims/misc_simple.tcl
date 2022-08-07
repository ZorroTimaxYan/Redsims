
# Copyright (c) 1995 The Regents of the University of California.
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
#	This product includes software developed by the Computer Systems
#	Engineering Group at Lawrence Berkeley Laboratory.
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
# @(#) $Header: /usr/local/share/doc/apache/cvs/autored/sims/misc_simple.tcl,v 1.1 2001/05/21 22:48:53 floyd Exp $
#

Object instproc exit args {
      set ns [Simulator instance]
      catch "$ns clearTimers"
      eval exit $args
}

Class TestSuite

TestSuite instproc init { {dotrace 1} } {
	global quiet
	$self instvar ns_ test_ node_ testName_ 
	$self instvar allchan_ namchan_ tinterval_
	if [catch "$self get-simulator" ns_] {
	    set ns_ [new Simulator]
	}
	if { $dotrace } {
                set allchan_ [open all.tr w]
               # $ns_ trace-all $allchan_
		set namchan_ [open all.nam w]
		if {$quiet == "false"} {
                	#$ns_ namtrace-all $namchan_
		}
	}

	set testName_ "$test_"
}

#
# Arrange for tcp source stats to be dumped for $tcpSrc every
# $interval seconds of simulation time
#
TestSuite instproc tcpDump { tcpSrc interval } {
	global quiet
	$self instvar dump_inst_ ns_
	if ![info exists dump_inst_($tcpSrc)] {
		set dump_inst_($tcpSrc) 1
		$ns_ at 0.0 "$self tcpDump $tcpSrc $interval"
		return
	}
	$ns_ at [expr [$ns_ now] + $interval] "$self tcpDump $tcpSrc $interval"
	set report [$ns_ now]/cwnd=[format "%.4f" [$tcpSrc set cwnd_]]/ssthresh=[$tcpSrc set ssthresh_]/ack=[$tcpSrc set ack_]
        if {$quiet == "false"} {
                puts $report
        }
}

#
# Arrange for time to be printed every
# $interval seconds of simulation time
#
TestSuite instproc timeDump { interval } {
	global quiet
	$self instvar dump_inst_ ns_
	if ![info exists dump_inst_] {
		set dump_inst_ 1
		$ns_ at 0.0 "$self timeDump $interval"
		return
	}
	$ns_ at [expr [$ns_ now] + $interval] "$self timeDump $interval"
	set report [$ns_ now]
        if {$quiet == "false"} {
                puts $report
        }
}

#
# Trace the TCP congestion window cwnd_.
#
TestSuite instproc enable_tracecwnd { ns tcp } { 
        $self instvar cwnd_chan_
        set cwnd_chan_ [open all.cwnd w]
        $tcp trace cwnd_
        $tcp attach $cwnd_chan_ 
}       
        
#
# Plot the TCP congestion window cwnd_.
#
TestSuite instproc plot_cwnd {} {
        global quiet
        $self instvar cwnd_chan_
        set awkCode {
              {
              if ($6 == "cwnd_") {
                print $1, $7 >> "temp.cwnd";
              } }
        }
        set f [open cwnd.xgr w]
        puts $f "TitleText: cwnd"
        puts $f "Device: Postscript"
 
        if { [info exists cwnd_chan_] } {
                close $cwnd_chan_  
        }
        exec rm -f temp.cwnd
        exec touch temp.cwnd
        
        exec awk $awkCode all.cwnd
        
        puts $f \"cwnd
        exec cat temp.cwnd >@ $f
        close $f                
        if {$quiet == "false"} {
                exec xgraph -bb -tk -x time -y cwnd cwnd.xgr &
        }               
}                               
                
TestSuite instproc cleanup { tfile testname } {
	$self instvar ns_ allchan_ namchan_
	$ns_ halt
	close $tfile
	if { [info exists allchan_] } {
		close $allchan_
	}       
	if { [info exists namchan_] } {
		close $namchan_
	}       
	$self finish $testname; # calls finish procedure in test suite file
}

TestSuite instproc cleanupAll { testname } {
	$self instvar ns_ allchan_ namchan_
	$ns_ halt
	if { [info exists allchan_] } {
		close $allchan_
	}       
	if { [info exists namchan_] } {
		close $namchan_
	}       
	$self finish $testname; # calls finish procedure in test suite file
}


TestSuite instproc openTrace { stopTime testName } {
	$self instvar ns_ allchan_ namchan_
	exec rm -f out.tr temp.rands
	set traceFile [open out.tr w]
	puts $traceFile "v testName $testName"
	$ns_ at $stopTime "$self cleanup $traceFile $testName"
	return $traceFile
}

TestSuite instproc traceQueues { node traceFile } {
        $self instvar ns_
        foreach nbr [$node neighbors] { 
                $ns_ trace-queue $node $nbr $traceFile
                [$ns_ link $node $nbr] trace-dynamics $ns_ $traceFile
        }
}
 
proc usage {} {
	global argv0
	puts stderr "Valid tests are:\t[get-subclasses TestSuite Test/]"
	exit 1
}

proc isProc? {cls prc} {
	if [catch "Object info subclass $cls/$prc" r] {
		global argv0
		puts stderr "$argv0: no such $cls: $prc"
		usage
	}
}

proc get-subclasses {cls pfx} {
	set ret ""
	set l [string length $pfx]

	set c $cls
	while {[llength $c] > 0} {
		set t [lindex $c 0]
		set c [lrange $c 1 end]
		if [string match ${pfx}* $t] {
			lappend ret [string range $t $l end]
		}
		eval lappend c [$t info subclass]
	}
	set ret
}

TestSuite proc runTest {} {
        global argc argv quiet

        set quiet false
        switch $argc {
                1 {
                        set test $argv
                        isProc? Test $test
                }
                2 {
                        set test [lindex $argv 0]
                        isProc? Test $test

                        set param [lindex $argv 1]
                        if {$param == "QUIET"} {
                                set quiet true 
                        } 
                }
                default {
                        usage
                }
        }
        set t [new Test/$test]
        $t run
}

### Local Variables:
### mode: tcl
### tcl-indent-level: 8
### tcl-default-application: ns
### End:
