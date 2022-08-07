Requirements:
Make sure you have a complete and working ns-2 distribution (you can verify this by running ./validate file under ns-2/ directory). You must also have xgraph, perl, and ns in your $PATH variable.

1) Figure 1 in this paper can be generated using the following command:
./single1.run 15 20 1 1 20 80 0 0.002

2) Figure 2 can be generated using the following command:
./single1.run 15 5 1 1 20 80 0 0.0

3) Figure 3 can be generated using the following command:
./single1.run 15 20 1 1 20 80 1 0.0

4) Each of the above commands dumps the output into "out.total". This file contains delay, 
throughput, and packet loss information. To generate the .eps figures (Figures 4 and 5), run 
the following command on out.total from steps 2) and 3) above.

./tradeoff.loss.pl out.total delay-loss ; followed by 
gv delay-loss.eps ; to view the .eps file

------------
5) To generate figure 6:
 ns adaptiveRed.tcl red2

6) For figure 7:
 ns adaptiveRed.tcl red2Adapt

7) For figure 8:
 ns adaptiveRed.tcl red3

8) For figure 9:
 ns adaptiveRed.tcl red3Adapt

Steps 5 through 9 output corresponding .ps files as well.

-----------

For generating figures 11 through 14:

9) For figure 11:
./w_q_oscil.run 15 0 1 0 0 10 20 80 0 0.002

10) For figure 12:
./w_q_oscil.run 15 20 1 1 0 10 20 80 0 0.002

11) For figure 13:
./w_q_oscil.run 15 0 1 0 0 10 20 80 1 0.0

12) For figure 14:
./w_q_oscil.run 15 20 1 1 0 10 20 80 1 0.0

In all four cases, you can change "plotQueue1{}" procedure call in "stop{}" procedure 
to "plotQueue{}" to generate .eps output

--------------

For generating figures 15 through 17:

13) For figure 15:
 ns adaptiveRed.tcl transient

14) For figure 16:
 ns adaptiveRed.tcl transient1

15) For figure 17: 
 ns adaptiveRed.tcl transient2

----------------

16) For generating figure 18:
 ns rt.tcl 60 15 1 1 20 0 10 20 80 1 rt.tcl ; follwed by
 gv reda_rt.eps ; to view the .eps file

