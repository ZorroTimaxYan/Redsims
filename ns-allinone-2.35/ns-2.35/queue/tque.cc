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
	ofstream ftimedelay1; //输出时延统计
	ofstream ftimedelay2; //输出时延统计仅仅有数值
	ofstream fperpkt; //输出间隔内入队包数

	int pktcnt_pers_td;//每间隔包数，时延统计
	double timeDelay;

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
	mytime = 0.01;
	pktcnt_pers = 0;
	count = 0;
	ftimedelay1.open("/home/yzr/common/mywork/tq_td.txt",ios::out);
	ftimedelay2.open("/home/yzr/common/mywork/tq_td_d.txt",ios::out);
	fperpkt.open("/home/yzr/common/mywork/perpkt_d.txt",ios::out);

	pktcnt_pers_td = 0;
	timeDelay = 0;
}
Tque::~Tque(){
	delete q_;
}

void Tque::enque(Packet *pkt) {
	pktcnt_pers_td++;
	double t = Scheduler::instance().clock();

	hdr_cmn *ch= hdr_cmn::access(pkt);
	// if(linkflag == 1){
	// 	cout << t-ch->ts_ <<endl;
	// }
	q_->enque(pkt);
	timeDelay += t-ch->ts_;
	//if(linkflag ==1) {
		pktcnt++;
		pktcnt_pers++;

	//}


	mytime += 10;
	//outfile1 << t << " " << pktcnt_pers << endl;
	//outfile2 <<  pktcnt_pers << endl;
	//pktcnt_pers = 0;
	//printf("%lf\n",t);
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

void Tque::putTd() {
	double t = Scheduler::instance().clock();
	double data;
	if(pktcnt_pers_td != 0) {
		data = timeDelay/pktcnt_pers_td;
		//cout << timeDelay <<endl;

	}else{
		data = 0;
	}
	ftimedelay1 << t << " " << data << endl;
	ftimedelay2<< data << endl;
	timeDelay = 0;
	pktcnt_pers_td = 0;
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
		} else if (strcmp(argv[1], "getTd") == 0) {
			putTd();
			return (TCL_OK);
		}

	}

	return (Queue::command(argc, argv));
}
