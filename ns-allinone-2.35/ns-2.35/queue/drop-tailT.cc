/* -*-	Mode:C++; c-basic-offset:8; tab-width:8; indent-tabs-mode:t -*- */
/*
 * Copyright (c) 1994 Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the Computer Systems
 *	Engineering Group at Lawrence Berkeley Laboratory.
 * 4. Neither the name of the University nor of the Laboratory may be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef lint
static const char rcsid[] =
    "@(#) $Header: /cvsroot/nsnam/ns-2/queue/drop-tail.cc,v 1.17 2004/10/28 23:35:37 haldar Exp $ (LBL)";
#endif

#include "drop-tailT.h"


static class DropTailTClass : public TclClass {
 public:
	DropTailTClass() : TclClass("Queue/DropTailT") {}
	TclObject* create(int argc, const char*const* argv) {
		int i = atoi(argv[4]);
		if(i == 1) {
			return (new DropTailT(1));
		} else {
			return (new DropTailT(2));
		}
		
	}
} class_drop_tailT;

void DropTailT::reset()
{
	Queue::reset();
}

int DropTailT::command(int argc, const char*const* argv) 
{
	if (argc==2) {
		if (strcmp(argv[1], "printstats") == 0) {
			print_summarystats();
			return (TCL_OK);
		}
 		if (strcmp(argv[1], "shrink-queue") == 0) {
 			shrink_queue();
 			return (TCL_OK);
 		}
 		if (strcmp(argv[1], "putTime") == 0) {
 			putTimedelay();
 			
 			return (TCL_OK);
 		}

	}
	if (argc == 3) {
		if (!strcmp(argv[1], "packetqueue-attach")) {
			delete q_;
			if (!(q_ = (PacketQueue*) TclObject::lookup(argv[2])))
				return (TCL_ERROR);
			else {
				pq_ = q_;
				return (TCL_OK);
			}
		}
	}
	return Queue::command(argc, argv);
}

/*
 * drop-tailT
 */
void DropTailT::enque(Packet* p)
{
/*
	if (summarystats) {
                Queue::updateStats(qib_?q_->byteLength():q_->length());
	}
*/
	if(linkflag == 1) {
		double t = Scheduler::instance().clock();
		hdr_cmn* ch = hdr_cmn::access(p);
		hdr_ip* iph = hdr_ip::access(p);
		//printf("linkflag=%d sd=%d dd=%d time=%lf  ptype=%d\n",linkflag, iph->saddr(), iph->daddr(), (t-ch->timestamp()),  ch->ptype());
		if(p != NULL && ch->ptype() != 5){
			pktcnt_pers_td++;
			timeDelay_pers += t-ch->timestamp();
			// if(t-ch->timestamp() < 0.022) {
			// 	printf("linkflag=%d sd=%d dd=%d time=%lf  ptype=%d\n",linkflag, iph->saddr(), iph->daddr(), (t-ch->timestamp()),  ch->ptype());
			// }
		}


	}

	q_->enque(p);
}

//AG if queue size changes, we drop excessive packets...
void DropTailT::shrink_queue() 
{
        int qlimBytes = qlim_ * mean_pktsize_;
	if (debug_)
		printf("shrink-queue: time %5.2f qlen %d, qlim %d\n",
 			Scheduler::instance().clock(),
			q_->length(), qlim_);
        while ((!qib_ && q_->length() > qlim_) || 
            (qib_ && q_->byteLength() > qlimBytes)) {
                if (drop_front_) { /* remove from head of queue */
                        Packet *pp = q_->deque();
                        drop(pp);
                } else {
                        Packet *pp = q_->tail();
                        q_->remove(pp);
                        drop(pp);
                }
        }
}

Packet* DropTailT::deque()
{
/*
	if (summarystats && &Scheduler::instance() != NULL) {
		Queue::updateStats(qib_?q_->byteLength():q_->length());
        }

*/		
		Packet* p = q_->deque();
		// if(p == NULL){
		// 	double t = Scheduler::instance().clock();
		// 	printf("linkflag=%d  t=%lf\n",linkflag, t);
		// }


	return p;
}

void DropTailT::print_summarystats()
{
	//double now = Scheduler::instance().clock();
        printf("True average queue: %5.3f", true_ave_);
        if (qib_)
                printf(" (in bytes)");
        printf(" time: %5.3f\n", total_time_);
}

//输出时延到文件
void DropTailT::putTimedelay() {
	
	double t = Scheduler::instance().clock();
	double data;
	//printf("%lf\n", timeDelay_pers);
	if(pktcnt_pers_td != 0) {
		data = timeDelay_pers/pktcnt_pers_td;
		ftimedelay1 << t << " " << data*1000 << endl;
		ftimedelay2 << data << endl;
	}

	timeDelay_pers = 0;
	pktcnt_pers_td = 0;
}