#include <string.h>
#include "queue.h"
#include <iostream>
#include <math.h>
#include <unistd.h>

using namespace std;

#define TimeSection 5

class PacketPDWRR;
class PDWRR;
static double totalTime = 0;

class PacketPDWRR : public PacketQueue {
	PacketPDWRR();
	friend class PDWRR;
protected :
	PacketPDWRR *prev;
	PacketPDWRR *next;
	int pkts; //标记当前包队列活跃状态，0为闲置，当前流剩余包数
	int pcount; //统计当前流总包数
	int dpcount; //统计当前流总丢包数
	double droprate_; //丢包率
	int bcount; //统计每条流的字节总数，用来获取数据量最大流
	int deficitCounter; //出队字节数差值
	int site; //当前流在drr队列里的角标
	int turn; //差额重置标志，0为重置
	double weight; //当前队列的权值
	double shape = 1.2; //Pareto的形状系数
	double Lf;
	double S; //平衡系数
	double t0; //一秒记录的开始时间
	double wt; //最近一次等待时间
	int *pkt_one; //当前记录的接收的包数,共记录5秒，作为预测的时间间隔
	int tflag; //pkt_one 5秒内每个时间点的角标

	inline PacketPDWRR * activate(PacketPDWRR *head) {
		if (head) {
			this->prev = head->prev;
			this->next = head;
			head->prev->next = this;
			head->prev = this;
			return head;
		}
		this->prev = this;
		this->next = this;
		return this;
	}
	inline PacketPDWRR * idle(PacketPDWRR *head) {
		if (head == this) {
			if (this->next == this)
				return 0;
			this->next->prev = this->prev;
			this->prev->next = this->next;
			return this->next;
		}
		this->next->prev = this->prev;
		this->prev->next = this->next;
		return head;
	}
	inline void forecastL() { //预测函数
		double Ex = 0;
		double Dx = 0;
		double Vk = 0;
		
		int result = 0;
		int one = 0;
		int i = 0;;
		
		//计算期望
		Ex = (double)(pkt_one[TimeSection] - pkt_one[0])/(double)TimeSection;
		Vk = Ex;
		
		//计算方差
		for(i=0; i<5; i++) {
			one = pkt_one[i+1]-pkt_one[i];
			Dx += pow(((double)one - Ex), 2);
		}
		Dx = Dx/TimeSection;
		Dx = sqrt(Dx);

		if(site == 1) {
			shape = 1.2;
		} else if(site == 2) {
			shape = 1.4;
		} else if(site == 3) {
			shape = 1.6;
		}

		//预测Lf等级
		if(shape == 1.2) {
			result = 1;
		} else if(shape == 1.4) {
			result = 2;
		} else if(shape == 1.6) {
			result = 3;
		}
		switch(result) {
			case 1: {
				if(Vk < (Ex-4*Dx)) { //Lk等级1
					Lf = 1.5;
				} else if(Vk>=(Ex-4*Dx) && Vk<(Ex-2*Dx)) {
					Lf = 2.7;			
				} else if(Vk>=(Ex-2*Dx) && Vk<Ex) {
					Lf = 3.6;			
				} else if(Vk>=Ex && Vk<(Ex+2*Dx)) {
					Lf = 4.0;			
				} else if(Vk>=(Ex+2*Dx) && Vk<(Ex+4*Dx)) {
					Lf = 4.1;			
				} else if(Vk>=(Ex+4*Dx)) {
					Lf = 4.8;			
				}
				break;
			}
			case 2: {
				if(Vk < (Ex-4*Dx)) { //Lk等级2
					Lf = 1.6;
				} else if(Vk>=(Ex-4*Dx) && Vk<(Ex-2*Dx)) {
					Lf = 2.7;			
				} else if(Vk>=(Ex-2*Dx) && Vk<Ex) {
					Lf = 3.4;			
				} else if(Vk>=Ex && Vk<(Ex+2*Dx)) {
					Lf = 3.8;			
				} else if(Vk>=(Ex+2*Dx) && Vk<(Ex+4*Dx)) {
					Lf = 4.0;			
				} else if(Vk>=(Ex+4*Dx)) {
					Lf = 4.7;			
				}
				break;
			}
			case 3: {
				if(Vk < (Ex-4*Dx)) { //Lk等级3
					Lf = 2.0;
				} else if(Vk>=(Ex-4*Dx) && Vk<(Ex-2*Dx)) {
					Lf = 2.9;			
				} else if(Vk>=(Ex-2*Dx) && Vk<Ex) {
					Lf = 3.4;			
				} else if(Vk>=Ex && Vk<(Ex+2*Dx)) {
					Lf = 3.6;			
				} else if(Vk>=(Ex+2*Dx) && Vk<(Ex+4*Dx)) {
					Lf = 3.8;			
				} else if(Vk>=(Ex+4*Dx)) {
					Lf = 4.5;			
				}
				break;
			}
		}
		
		//调整权值
		double dw = 0;
		if(Lf < 3) {
			dw = (Lf-3)/2;
		} else if (Lf>=3 && Lf<=4) {
			dw = 0;
		} else {
			dw = (Lf-4)/2;
		}
		weight += dw;
		//printf("%d队列,权值调整为:%lf\n",site,weight);
	}
	
};

PacketPDWRR::PacketPDWRR(){
	prev = 0;
	next = 0;
	pkts = 0; //标记当前包队列活跃状态，0为闲置，当前流剩余包数
	pcount = 0; //统计当前流总包数
	dpcount = 0; //统计当前流总丢包数
	droprate_ = 0; //丢包率
	bcount = 0; //统计每条流的字节总数，用来获取数据量最大流
	deficitCounter = 0; //出队字节数差值
	site = 0; //当前流在drr队列里的角标
	turn = 0; //差额重置标志，0为重置
	weight = 0; //当前队列的权值
	shape = 1.2; //Pareto的形状系数
	Lf = 0;
	S = 0; //平衡系数
	t0 = 0; //一秒记录的开始时间
	wt = 0; //最近一次等待时间
	pkt_one = new int[TimeSection+1]; //当前记录的接收的包数,共记录5秒，作为预测的时间间隔
	tflag = 0; //pkt_one 5秒内每个时间点的角标	
}

class PDWRR : public Queue {
public :
	PDWRR();

	virtual int command(int argc, const char*const* argv);
	Packet *deque(void);
	void enque(Packet *pkt);
	
protected :
	PacketPDWRR *pdwrr; //所有的pdwrr包队列流
	PacketPDWRR *curr; //实际操作的目标流
	int buckets_; //数据流缓冲区总数，也就是桶
	int blimit_; //总缓冲区大小
	int quantum_; //总的服务量子q，轮询一次发送最大字节数
	int bytecnt; //所有流总的字节数
	int pktcnt; //所有流总的数据包数 
	int flwcnt; //当前活跃流总数
	double *levels; //优先级数组，数组内容是流的角标+1，flwcnt-角标是权值
	int *pktarr; //对应流数据包大小
	int cerprique; //优先角标
	double *onTime; //等待开始时间组
	double *offTime; //等待结束时间组
	int predequeSite; //上一个出队的队列；

	int sbytecnt = 0; //发送数据量
	double fdtime = 0; //第一次发送时间
	int ebytecnt = 0; //接收数据量
	double efdtime = 0; //第一次接收时间

	double droprate_; //丢包率
	double droprate1_; //丢包率
	double droprate2_; //丢包率
	double droprate3_; //丢包率
	int totaldpcount = 0; //总丢包数
	double totaldroprate; //总丢包率

	inline void rearr(PacketPDWRR *head) { //重新调整队列顺序
		
		
		double nextS = levels[cerprique];
		int empty = 1;
		if(head) {
			
			delete []levels;		
		
			levels = new double[flwcnt];
			PacketPDWRR *q;
			q = head;
			int i,j;
			double tmp;

			//将平衡系数S以乱序记录进levels数组
			for(i=0; i<flwcnt; i++) {
				levels[i] = q->S;
				if(q->S == nextS) { //判断下一个需要出队的队列是否存在
					empty = 0;
				}
				q = q->next;
			}			

			//levels数组从大到小排序
			for(i=0; i<flwcnt; i++) {
				for(j = 0; j<flwcnt-i-1; j++) {
					if(levels[j] < levels[j+1]) {
						tmp = levels[j];
						levels[j] = levels[j+1];
						levels[j+1] = tmp;				
					}			
				}	
			}

			//还原下一个需要出队的优先标志	
			if(!empty) {
				for(i=0; i<flwcnt; i++) {
					if(levels[i] == nextS) {
						cerprique = i;
					}
				}
			} else {
				cerprique = 0;
			}

		}
		
	}

	inline int gettotalTime(PacketPDWRR *curr) {
		PacketPDWRR *tmp;
		tmp = curr;
		int i = 0;

		totalTime = 0;
		while(i < flwcnt) {
			if(tmp->wt == 0) {
			
				return 1; //存在等待时间为空的流，结束统计
			}

			totalTime += tmp->wt;
			tmp = tmp->next;
			i++;
		}
		

		for(i=0; i<flwcnt; i++) {
			if(tmp->Lf != 0) {
				tmp->S = tmp->Lf*tmp->weight*(tmp->wt/totalTime);
				tmp->Lf = 0;
			}

			tmp->wt = 0;
			tmp = tmp->next;
		}
		rearr(curr);
		return 0;
	}	
	
	inline PacketPDWRR *moveMaxS(PacketPDWRR *curr) {
		PacketPDWRR *tmp;
		tmp = curr;
		int flag = 0;
		while(flag != -1) {
			//cout << tmp->S<< "    " << levels[cerprique] << "   "<< cerprique <<endl;
			if(tmp->S == levels[cerprique]) {
				flag = -1;
			} else {
				tmp = tmp->next;
							
			}		
		}

		//出队流切换，记录结束等待时间
		if(tmp->site != predequeSite) {
			offTime[tmp->site] = Scheduler::instance().clock();
			tmp->wt = offTime[tmp->site] - onTime[tmp->site];
			gettotalTime(curr);
		}		
		
		return tmp;
		
	}
	
	inline PacketPDWRR *getMaxflow (PacketPDWRR *curr) { //returns flow with max pkts
		int i;
		PacketPDWRR *tmp;
		PacketPDWRR *maxflow=curr;
		for (i=0,tmp=curr; i < flwcnt; i++,tmp=tmp->next) {
			if (maxflow->bcount < tmp->bcount)
				maxflow=tmp;
		}
		return maxflow;
	}
	
};





//在OTCL里面注册我的DWRR类
static class PDWRRClass : public TclClass {
public :
	PDWRRClass() : TclClass("Queue/PDWRR") {}
	TclObject *create(int, const char*const*) {
		return (new PDWRR);	
	}
} class_pdwrr;

PDWRR::PDWRR() {
	
	pdwrr = 0;
	curr = 0;
	buckets_ = 16;
	blimit_ = 0; 
	quantum_ = 128; 
	bytecnt = 0; 
	pktcnt = 0; 
	flwcnt = 0; 
	levels =  new double[buckets_]; 
	pktarr = 0;
	cerprique = 0; 
	onTime = 0;
	offTime = 0;
	predequeSite = 0;

	sbytecnt = 0;
	fdtime = 0;
	ebytecnt = 0;
	efdtime = 0;

	droprate_ = 0;
	droprate1_ = 0;
	droprate2_ = 0;
	droprate3_ = 0;
	totaldpcount = 0;
	totaldroprate = 0;
	
	bind("buckets_", &buckets_);
	bind("blimit_", &blimit_);
	bind("droprate_", &droprate_);
	bind("droprate1_", &droprate1_);
	bind("droprate2_", &droprate2_);
	bind("droprate3_", &droprate3_);
	bind("totaldpcount", &totaldpcount);
}

void PDWRR::enque(Packet *pkt) {

	//cout << "入队" << endl;	

	PacketPDWRR *q,*remq;
	int which;
	double curtime = Scheduler::instance().clock();  //仿真机当前的时间
	hdr_cmn *ch= hdr_cmn::access(pkt);	//packet.h内结构体  得到数据包大小的字符数组，强制转换为hdr_cmn型
	hdr_ip *iph = hdr_ip::access(pkt);	//ip.h内结构体  得到数据包大小的字符数组，强制转换为hdr_ip型;
	if (!pdwrr) {
		pdwrr = new PacketPDWRR[buckets_];
		onTime = new double[buckets_];
		offTime = new double[buckets_];
	}
	
	//为了仿真测试	
	if(iph->saddr()>=5 && iph->saddr()<=104) {
		which = 1;
	} else if(iph->saddr()>=105 && iph->saddr()<=204) {
		which = 2;
	} else if(iph->saddr()>=205 && iph->saddr()<=304) {
		which = 3;
	}
	
	//which= iph->saddr() % buckets_;
	q=&pdwrr[which];
	q->enque(pkt);
	++q->pkts;
	++q->pcount;
	++pktcnt;
	q->bcount += ch->size();
	bytecnt +=ch->size();

	if(q->pcount == 1) {
		if(which ==1) {
			q->weight = 3;
			q->shape = 1.2;
		} else if(which ==2) {
			q->weight = 2;
			q->shape = 1.4;
		} else if(which ==3) {
			q->weight = 1;
			q->shape = 1.6;
		}

		//q->weight = iph->saddr(); //权值设置为节点编号
		q->S = q->weight; //把S作为用权值初始化
		q->t0 = curtime;
		q->pkt_one[0] = 0;
	}

	if (q->pkts==1) {
		curr = q->activate(curr);
		q->site = which;
		onTime[q->site] = Scheduler::instance().clock();
		q->deficitCounter=0;	//差额设置为0
		++flwcnt;	//活跃流总数+1
		rearr(curr);
	}

	//当前时间和t0记录的时间相差大于或等于1秒时，进行记录
	if(curtime >= q->t0+1) {
		//printf("入队：%d号流，剩余%d个包\n",q->site,q->pkts);
		//记录pkt_one以及tflag;
		q->pkt_one[q->tflag] = q->pcount-1;
		if(q->pcount == 0) {
			q->pkt_one[q->tflag] = 0;
		}
		
		//角标tflag增加，保持在需要记录的那一秒，如果当前为第5秒则进行预测并归零
		if(q->tflag == TimeSection) {
			q->forecastL();
			q->tflag = 0;
		} else {
			q->tflag++;
		}
		
		q->t0 = curtime;
		
	}
	//cout << blimit_ <<endl;	
	while (bytecnt > blimit_) {  //超出的数据处理
		Packet *p;
		hdr_cmn *remch;
		remq=getMaxflow(curr);	//找到含有最多比特数的流，让它进行出队
		p=remq->deque();
		remch=hdr_cmn::access(p);
		remq->bcount -= remch->size();
		bytecnt -= remch->size();
		remq->dpcount++;
		totaldpcount++;
		totaldroprate = (double)totaldpcount / (double)pktcnt;
		remq->droprate_ = (double)remq->dpcount / (double)remq->pcount;
		if(remq->site == 1) {
			droprate1_ =  remq->droprate_;
		}
		if(remq->site == 2) {
			droprate2_ =  remq->droprate_;
		}
		if(remq->site == 3) {
			droprate3_ =  remq->droprate_;
		}
	//	if(remq->site == 3) {
			//printf("队列%d丢包率为:%lf\n",remq->site,remq->droprate_);
			//printf("队列%d丢包数为:%d\n",remq->site,remq->dpcount);
	//	}

		drop(p);
		--remq->pkts;
		if (remq->pkts==0) {		
			
			onTime[remq->site] = 0; //流清空，等待时间归零
			curr = remq->idle(curr);
			--flwcnt;


			if(remq->S == levels[cerprique]) {
				cerprique++;
				if(cerprique >= flwcnt) {
					cerprique = 0;			
				}
			}	
			rearr(curr);
		}
	}

}

Packet *PDWRR::deque() {
	

	hdr_cmn *ch;
	Packet *pkt=0;
	if (bytecnt==0) {
		//fprintf (stderr,"No active flow\n");
		return(0);
	}
	

	
	while (!pkt) {	//包为空时
		curr = moveMaxS(curr);
	
		if (!curr->turn) {
			curr->deficitCounter+=curr->weight*quantum_;	//将差额设置为单个流允许的最大发送字节
			curr->turn=1;
		}
		
		pkt=curr->lookup(0);  //当前活跃流中的下一个包
		ch=hdr_cmn::access(pkt);
		if (curr->deficitCounter >= ch->size()) {
			curr->deficitCounter -= ch->size();
			pkt=curr->deque();	//pkt为包队列头
			predequeSite = curr->site;			

			if(sbytecnt == 0) {
				fdtime = Scheduler::instance().clock();
			}
			double tt = Scheduler::instance().clock();		
			sbytecnt += ch->size();			
			if(tt>=fdtime+1){
				//printf("当前一秒内发送的数据大小为%d字节\n",sbytecnt);
				sbytecnt = 0;
				fdtime = Scheduler::instance().clock();		
			}

			curr->bcount -= ch->size();
			--curr->pkts;
			bytecnt -= ch->size();

			//printf("出队：%d号流，剩余%d个包\n",curr->site,curr->pkts);
			//cout << bytecnt << endl;
			if (curr->pkts == 0) {
				onTime[curr->site] = 0; //流清空，等待时间归零
				curr->turn=0;
				--flwcnt;
				curr->deficitCounter=0;
				curr=curr->idle(curr);

				cerprique++;
				if(cerprique >= flwcnt) {
					cerprique = 0;			
				}
				rearr(curr);
			}
			
			return pkt;
		}
		else {
			curr->turn=0;
			cerprique++;
			onTime[curr->site] = Scheduler::instance().clock();
			if(cerprique >= flwcnt) {
				cerprique = 0;			
			}
			pkt=0;
		}
	}
	return 0;    // not reached
}

int PDWRR::command(int argc, const char*const* argv)
{
	if (argc==3) {
		if (strcmp(argv[1], "blimit") == 0) {
			blimit_ = atoi(argv[2]);
			if (bytecnt > blimit_)
				{
					fprintf (stderr,"More packets in buffer than the new limit");
					exit (1);
				}
			return (TCL_OK);
		}
		
	}

	return (Queue::command(argc, argv));
}

