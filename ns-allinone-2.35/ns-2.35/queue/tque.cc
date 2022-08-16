#include <string.h>
#include "queue.h"
#include <iostream>
#include <fstream>
#include <math.h>
#include "random.h"
using namespace std;

class Tque;
class Tque : public Queue {
public :
	Tque();
	~Tque();
	void over();
	void totalpkt();
	void putTd();
protected :
	virtual int command(int argc, const char*const* argv);
	virtual Packet *deque(void);
	virtual void enque(Packet *pkt);

	PacketQueue *q_ = new PacketQueue(); //包队列(缓冲区)
	double mytime; //用于统计记时
	int pktcnt_pers; //每秒入队包数
	int pktcnt; //总包数
	int count; //统计个数
	ofstream fperpkt; //输出间隔内入队包数
	ofstream test_itv; //输出包之间的时间间隔
	double tin; //统计两个包之间的时间间隔

};

//在OTCL里面注册我的Tque类
static class TqueClass : public TclClass {
public :
	TqueClass() : TclClass("Queue/Tque") {}
	TclObject *create(int argc, const char*const* argv) {
		return (new Tque());
	}
} class_tque;

Tque::Tque() {
	mytime = 0;
	pktcnt_pers = 0;
	count = 0;
	fperpkt.open("/home/yzr/common/mywork/perpkt_d.txt",ios::out);
	test_itv.open("/home/yzr/common/mywork/interval.txt",ios::out);

	tin = -1;
}
Tque::~Tque(){
	delete q_;
}

void Tque::enque(Packet *pkt) {
	double t = Scheduler::instance().clock();
	hdr_cmn* mych = hdr_cmn::access(pkt);
	hdr_ip* myiph = hdr_ip::access(pkt);
	// if(mych->ptype() == 0 )
	//printf("sd=%d dd=%d time=%lf  ptype=%d\n",myiph->saddr(), myiph->daddr(), (t-mych->timestamp()),  mych->ptype());

	q_->enque(pkt);

	if(mych->ptype() == 28){
		if(tin != -1 ) {
			
			test_itv << t-tin << endl;
		}
		tin = t;	
	}
	pktcnt++;
	pktcnt_pers++;



	if(t >= mytime) {
		printf("%lf\n",t);
		mytime += 10;
	}
	
	//outfile1 << t << " " << pktcnt_pers << endl;
	//outfile2 <<  pktcnt_pers << endl;
	//pktcnt_pers = 0;

}

Packet *Tque::deque() {
		return (q_->deque());
}

void Tque::over() {
	double t = Scheduler::instance().clock();
	//outfile1 << t << " " << pktcnt_pers << endl;
	fperpkt<<  pktcnt_pers << endl;
	//cout << pktcnt_pers << endl;
	pktcnt_pers = 0;
}

void Tque::totalpkt() {
	//if(linkflag ==1) {
	count++;
		cout << count << "tque的总包数=" <<pktcnt << endl;
		pktcnt = 0;
	//}
}

int Tque::command(int argc, const char*const* argv)
{
	if (argc==2) {
		if (strcmp(argv[1], "writeover") == 0) {
			
			over();
			return (TCL_OK);
		} else if (strcmp(argv[1], "totalpkt") == 0) {
			totalpkt();
			return (TCL_OK);
		}

	}

	return (Queue::command(argc, argv));
}
