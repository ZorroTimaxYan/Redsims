#include <string.h>
#include "queue.h"
#include <iostream>

using namespace std;

class PacketDWRR;
class DWRR;

class PacketDWRR : public PacketQueue {
	PacketDWRR(): prev(0),next(0),pkts(0),bcount(0),deficitCounter(0),site(0),turn(0){}
	friend class DWRR;
protected :
	PacketDWRR *prev;
	PacketDWRR *next;
	int pkts; //标记当前包队列活跃状态，0为闲置
	int bcount; //统计每条流的字节总数，用来获取数据量最大流
	int deficitCounter; //出队字节数差值
	int site; //当前流在drr队列里的角标
	int turn; //差额重置标志，0为重置
	int weight; //当前队列的权值

	inline PacketDWRR * activate(PacketDWRR *head) {
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
	inline PacketDWRR * idle(PacketDWRR *head) {
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

	
};

class DWRR : public Queue {
public :
	DWRR();
	virtual int command(int argc, const char*const* argv);
	Packet *deque(void);
	void enque(Packet *pkt);
protected :
	PacketDWRR *dwrr; //所有的dwrr包队列流
	PacketDWRR *curr; //实际操作的目标流
	int buckets_; //数据流缓冲区总数，也就是桶
	int blimit_; //总缓冲区大小
	int quantum_; //总的服务量子q，轮询一次发送最大字节数
	int bytecnt; //所有流总的字节数
	int pktcnt; //所有流总的数据包数 
	int flwcnt; //当前活跃流总数
	int *weights; //权值数组，数组内容是流的角标+1，flwcnt-角标是权值
	int *pktarr; //对应流数据包大小
	int cerprique; //优先角标
	
	inline void rearr(PacketDWRR *head) {
		if(head) {
			
	
			delete []weights;		
		
			weights = new int[flwcnt];
			PacketDWRR *q;
			q = head;
			int i,j,tmp;;
			
			//将权值以乱序记录进weights数组
			for(i=0; i<flwcnt; i++) {
				weights[i] = q->weight;
				q = q->next;
			}
			
			//weights数组从大到小排序
			for(i=0; i<flwcnt; i++) {
				for(j = 0; j<flwcnt-i-1; j++) {
					if(weights[j] < weights[j+1]) {
						tmp = weights[j];
						weights[j] = weights[j+1];
						weights[j+1] = tmp;				
					}			
				}	
			}

			cerprique = 0;
		}
		
	}

	inline PacketDWRR *moveMaxweight(PacketDWRR *curr) {	
		PacketDWRR *tmp;
		tmp = curr;
		int flag = 0;
		while(flag != -1) {
			if(tmp->weight == weights[cerprique]) {
				flag = -1;
			} else {
				tmp = tmp->next;			
			}		
		}
		return tmp;
	}
	
	inline PacketDWRR *getMaxflow (PacketDWRR *curr) { //returns flow with max pkts
		int i;
		PacketDWRR *tmp;
		PacketDWRR *maxflow=curr;
		for (i=0,tmp=curr; i < flwcnt; i++,tmp=tmp->next) {
			if (maxflow->bcount < tmp->bcount)
				maxflow=tmp;
		}
		return maxflow;
	}

public :
	inline int length () {
		return pktcnt;	
	}
	inline int blength () {
		return bytecnt;
	}
};

//在OTCL里面注册我的DWRR类
static class DWRRClass : public TclClass {
public :
	DWRRClass() : TclClass("Queue/DWRR") {}
	TclObject *create(int, const char*const*) {
		return (new DWRR);	
	}
} class_dwrr;

DWRR::DWRR() {
	dwrr = 0;
	curr = 0;
	buckets_ = 16;
	blimit_ = 20000;
	quantum_ = 2000;
	bytecnt = 0;
	pktcnt = 0;
	flwcnt = 0;
	
	weights = new int[buckets_];
	pktarr = 0;
	cerprique = 0;

	bind("buckets_", &buckets_);
	bind("blimit_", &blimit_);
}

void DWRR::enque(Packet *pkt) {
	PacketDWRR *q,*remq;
	int which;

	hdr_cmn *ch= hdr_cmn::access(pkt);	//packet.h内结构体  得到数据包大小的字符数组，强制转换为hdr_cmn型
	hdr_ip *iph = hdr_ip::access(pkt);	//ip.h内结构体  得到数据包大小的字符数组，强制转换为hdr_ip型
	if (!dwrr)
		dwrr=new PacketDWRR[buckets_];
	which= iph->saddr() % buckets_;
	q=&dwrr[which];
	q->enque(pkt);
	++q->pkts;
	++pktcnt;
	q->bcount += ch->size();
	bytecnt +=ch->size();

	if (q->pkts==1)
		{
			curr = q->activate(curr);
			q->deficitCounter=0;	//差额设置为0
			q->weight = iph->saddr(); //权值设置为节点编号
			q->site = which;
			++flwcnt;	//活跃流总数+1
			rearr(curr);
		}

	//printf("入队：%d号流，剩余%d个包\n",q->site,q->pkts);	

	while (bytecnt > blimit_) {  //超出的数据处理
		
		Packet *p;
		hdr_cmn *remch;
		remq=getMaxflow(curr);	//找到含有最多比特数的流，让它进行出队
		p=remq->deque();
		remch=hdr_cmn::access(p);
		remq->bcount -= remch->size();
		bytecnt -= remch->size();
		drop(p);
		--remq->pkts;
		--pktcnt;
		if (remq->pkts==0) {
			curr = remq->idle(curr);
			--flwcnt;
			rearr(curr);
		}
	}
}

Packet *DWRR::deque() {
	


	hdr_cmn *ch;
	Packet *pkt=0;
	if (bytecnt==0) {
		//fprintf (stderr,"No active flow\n");
		return(0);
	}
	

	
	while (!pkt) {	//包为空时
		
		curr = moveMaxweight(curr);
		if (!curr->turn) {
			curr->deficitCounter+=curr->weight*quantum_;	//将差额设置为但个流允许的最大发送字节
			curr->turn=1;
		}

		pkt=curr->lookup(0);  //当前活跃流中的下一个包
		ch=hdr_cmn::access(pkt);
		if (curr->deficitCounter >= ch->size()) {
			curr->deficitCounter -= ch->size();
			pkt=curr->deque();	//pkt为包队列头
			
			
			curr->bcount -= ch->size();
			--curr->pkts;
			--pktcnt;
			bytecnt -= ch->size();
			
			printf("出队：%d号流，剩余%d个包,，剩余差额%d\n",curr->site,curr->pkts,curr->deficitCounter);
			if (curr->pkts == 0) {

				curr->turn=0;
				--flwcnt;
				curr->deficitCounter=0;
				curr=curr->idle(curr);
				rearr(curr);
			}
			
			return pkt;
		}
		else {

			curr->turn=0;
			cerprique++;
			
			if(cerprique >= flwcnt) {
				cerprique = 0;			
			}
			pkt=0;
		//cout << cerprique << endl;
		}
	}
	return 0;    // not reached
}

int DWRR::command(int argc, const char*const* argv)
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
